package com.aegisvault.app.data.security

import android.content.SharedPreferences
import androidx.core.content.edit
import com.aegisvault.app.domain.model.PinValidationResult
import com.aegisvault.app.domain.repository.PinCredentialStore
import com.aegisvault.app.util.Constants
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Stores only a salted PBKDF2 hash of the PIN, never the raw digits, inside an
 * EncryptedSharedPreferences file (AES-256-GCM at rest) — layered defense rather than
 * reliance on a single mechanism. Failed attempts escalate into a persisted lockout window.
 */
@Singleton
class PinCredentialStoreImpl @Inject constructor(
    @PinBillingPrefs private val prefs: SharedPreferences,
) : PinCredentialStore {

    private companion object {
        const val KEY_SALT = "pin_salt"
        const val KEY_HASH = "pin_hash"
        const val KEY_ATTEMPTS = "pin_failed_attempts"
        const val KEY_LOCKOUT_UNTIL = "pin_lockout_until"
        const val PBKDF2_ITERATIONS = 120_000
        const val KEY_LENGTH_BITS = 256
    }

    private val _failures = MutableSharedFlow<PinValidationResult>(extraBufferCapacity = 1)
    override fun observeFailures(): Flow<PinValidationResult> = _failures.asSharedFlow()

    override fun isPinConfigured(): Boolean = prefs.contains(KEY_HASH)

    override fun setPin(pin: String) {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val hash = deriveHash(pin, salt)
        prefs.edit {
            putString(KEY_SALT, salt.toHexString())
            putString(KEY_HASH, hash.toHexString())
            putInt(KEY_ATTEMPTS, 0)
            putLong(KEY_LOCKOUT_UNTIL, 0L)
        }
    }

    override fun validatePin(pin: String): PinValidationResult {
        if (!isPinConfigured()) return PinValidationResult.NoPinConfigured

        val lockoutUntil = prefs.getLong(KEY_LOCKOUT_UNTIL, 0L)
        val now = System.currentTimeMillis()
        if (lockoutUntil > now) return PinValidationResult.LockedOut(lockoutUntil)

        val storedSalt = prefs.getString(KEY_SALT, null)?.hexToByteArray() ?: return PinValidationResult.NoPinConfigured
        val storedHash = prefs.getString(KEY_HASH, null)?.hexToByteArray() ?: return PinValidationResult.NoPinConfigured
        val candidateHash = deriveHash(pin, storedSalt)

        return if (MessageDigest.isEqual(candidateHash, storedHash)) {
            prefs.edit { putInt(KEY_ATTEMPTS, 0); putLong(KEY_LOCKOUT_UNTIL, 0L) }
            PinValidationResult.Success
        } else {
            val attempts = prefs.getInt(KEY_ATTEMPTS, 0) + 1
            val result = if (attempts >= Constants.MAX_PIN_ATTEMPTS) {
                val unlockAt = now + Constants.PIN_LOCKOUT_MILLIS
                prefs.edit { putInt(KEY_ATTEMPTS, 0); putLong(KEY_LOCKOUT_UNTIL, unlockAt) }
                PinValidationResult.LockedOut(unlockAt)
            } else {
                prefs.edit { putInt(KEY_ATTEMPTS, attempts) }
                PinValidationResult.Failure(Constants.MAX_PIN_ATTEMPTS - attempts)
            }
            _failures.tryEmit(result)
            result
        }
    }

    override fun clearPin() {
        prefs.edit {
            remove(KEY_SALT); remove(KEY_HASH); remove(KEY_ATTEMPTS); remove(KEY_LOCKOUT_UNTIL)
        }
    }

    private fun deriveHash(pin: String, salt: ByteArray): ByteArray {
        val spec = PBEKeySpec(pin.toCharArray(), salt, PBKDF2_ITERATIONS, KEY_LENGTH_BITS)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        return factory.generateSecret(spec).encoded
    }

    private fun ByteArray.toHexString(): String = joinToString("") { "%02x".format(it) }
    private fun String.hexToByteArray(): ByteArray = chunked(2).map { it.toInt(16).toByte() }.toByteArray()
}
