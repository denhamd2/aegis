package com.aegisvault.app.data.backup

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import javax.crypto.AEADBadTagException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class VaultArchiveCryptoTest {

    @Test
    fun `random salts are unique`() {
        val salt1 = VaultArchiveCrypto.randomSalt()
        val salt2 = VaultArchiveCrypto.randomSalt()
        assertFalse(salt1.contentEquals(salt2))
        assertTrue(salt1.size == VaultArchiveCrypto.SALT_LENGTH_BYTES)
    }

    @Test
    fun `encryptBytes then decryptBytes round-trips the plaintext`() {
        val salt = VaultArchiveCrypto.randomSalt()
        val key = VaultArchiveCrypto.deriveKey("correct horse battery staple".toCharArray(), salt, iterations = 1000)
        val plaintext = "the manifest json goes here".toByteArray(Charsets.UTF_8)

        val ciphertext = VaultArchiveCrypto.encryptBytes(key, plaintext)
        val decrypted = VaultArchiveCrypto.decryptBytes(key, ciphertext)

        assertArrayEquals(plaintext, decrypted)
    }

    @Test
    fun `encryptBytes uses a fresh IV every call`() {
        val salt = VaultArchiveCrypto.randomSalt()
        val key = VaultArchiveCrypto.deriveKey("password".toCharArray(), salt, iterations = 1000)
        val plaintext = "same plaintext both times".toByteArray(Charsets.UTF_8)

        val first = VaultArchiveCrypto.encryptBytes(key, plaintext)
        val second = VaultArchiveCrypto.encryptBytes(key, plaintext)

        val firstIv = first.copyOfRange(0, VaultArchiveCrypto.GCM_IV_LENGTH_BYTES)
        val secondIv = second.copyOfRange(0, VaultArchiveCrypto.GCM_IV_LENGTH_BYTES)
        assertFalse(firstIv.contentEquals(secondIv))
        assertFalse(first.contentEquals(second))
    }

    @Test
    fun `decryptBytes with wrong password throws AEADBadTagException`() {
        val salt = VaultArchiveCrypto.randomSalt()
        val rightKey = VaultArchiveCrypto.deriveKey("correct password".toCharArray(), salt, iterations = 1000)
        val wrongKey = VaultArchiveCrypto.deriveKey("wrong password".toCharArray(), salt, iterations = 1000)
        val ciphertext = VaultArchiveCrypto.encryptBytes(rightKey, "secret".toByteArray(Charsets.UTF_8))

        assertThrows(AEADBadTagException::class.java) {
            VaultArchiveCrypto.decryptBytes(wrongKey, ciphertext)
        }
    }

    @Test
    fun `streaming encrypt then decrypt round-trips large content`() {
        val salt = VaultArchiveCrypto.randomSalt()
        val key = VaultArchiveCrypto.deriveKey("password".toCharArray(), salt, iterations = 1000)
        val plaintext = ByteArray(500_000) { (it % 256).toByte() }

        val sink = ByteArrayOutputStream()
        VaultArchiveCrypto.encryptingOutputStream(key, sink).use { out -> out.write(plaintext) }

        val decrypted = VaultArchiveCrypto.decryptingInputStream(key, ByteArrayInputStream(sink.toByteArray())).use { it.readBytes() }

        assertArrayEquals(plaintext, decrypted)
    }
}
