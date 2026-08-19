package com.aegisvault.app.domain.usecase

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject

enum class BiometricAvailability { AVAILABLE, NO_HARDWARE, NOT_ENROLLED, UNAVAILABLE }

class ValidateBiometricAvailabilityUseCase @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    operator fun invoke(): BiometricAvailability {
        val manager = BiometricManager.from(context)
        return when (manager.canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> BiometricAvailability.AVAILABLE
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> BiometricAvailability.NOT_ENROLLED
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE,
            -> BiometricAvailability.NO_HARDWARE
            else -> BiometricAvailability.UNAVAILABLE
        }
    }
}
