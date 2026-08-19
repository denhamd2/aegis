package com.aegisvault.app.data.backup

import java.io.InputStream
import java.io.OutputStream
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Pure javax.crypto/java.security helper for the vault export/import archive format —
 * no Android framework dependency, so it's testable on the plain JVM.
 *
 * Every encrypted entry is `[12-byte random IV] || [AES-GCM ciphertext with 16-byte tag]`.
 * The password-derived key is device-independent, unlike the AndroidKeyStore-backed key
 * [com.aegisvault.app.data.security.EncryptedFileManager] uses for on-device vault storage —
 * that's what makes the archive portable across installs.
 */
object VaultArchiveCrypto {
    const val PBKDF2_ITERATIONS = 210_000
    const val KEY_LENGTH_BITS = 256
    const val SALT_LENGTH_BYTES = 16
    const val GCM_IV_LENGTH_BYTES = 12
    const val GCM_TAG_LENGTH_BITS = 128
    private const val KEY_ALGORITHM = "PBKDF2WithHmacSHA256"
    private const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"

    private val secureRandom = SecureRandom()

    fun randomSalt(): ByteArray = ByteArray(SALT_LENGTH_BYTES).also { secureRandom.nextBytes(it) }

    fun deriveKey(password: CharArray, salt: ByteArray, iterations: Int = PBKDF2_ITERATIONS): SecretKey {
        val factory = SecretKeyFactory.getInstance(KEY_ALGORITHM)
        val spec = PBEKeySpec(password, salt, iterations, KEY_LENGTH_BITS)
        return try {
            SecretKeySpec(factory.generateSecret(spec).encoded, "AES")
        } finally {
            spec.clearPassword()
        }
    }

    /** Full-buffer encrypt for small payloads (the archive manifest). */
    fun encryptBytes(key: SecretKey, plaintext: ByteArray): ByteArray {
        val iv = ByteArray(GCM_IV_LENGTH_BYTES).also { secureRandom.nextBytes(it) }
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
        return iv + cipher.doFinal(plaintext)
    }

    /** Full-buffer decrypt matching [encryptBytes]. Throws [javax.crypto.AEADBadTagException]
     * on a wrong key or tampered data — callers use this to detect a wrong archive password. */
    fun decryptBytes(key: SecretKey, ivAndCiphertext: ByteArray): ByteArray {
        require(ivAndCiphertext.size > GCM_IV_LENGTH_BYTES) { "Archive entry too short to contain an IV" }
        val iv = ivAndCiphertext.copyOfRange(0, GCM_IV_LENGTH_BYTES)
        val ciphertext = ivAndCiphertext.copyOfRange(GCM_IV_LENGTH_BYTES, ivAndCiphertext.size)
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
        return cipher.doFinal(ciphertext)
    }

    /** Streaming encrypt for large payloads (vault item content). Writes a fresh random IV
     * header to [sink] before returning a stream that encrypts everything written to it. */
    fun encryptingOutputStream(key: SecretKey, sink: OutputStream): OutputStream {
        val iv = ByteArray(GCM_IV_LENGTH_BYTES).also { secureRandom.nextBytes(it) }
        sink.write(iv)
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
        return CipherOutputStream(sink, cipher)
    }

    /** Streaming decrypt matching [encryptingOutputStream]: reads the IV header from [source]
     * first, then returns a stream that transparently decrypts the rest. */
    fun decryptingInputStream(key: SecretKey, source: InputStream): InputStream {
        val iv = ByteArray(GCM_IV_LENGTH_BYTES)
        var read = 0
        while (read < iv.size) {
            val n = source.read(iv, read, iv.size - read)
            if (n == -1) error("Archive entry truncated before IV could be read")
            read += n
        }
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
        return CipherInputStream(source, cipher)
    }
}
