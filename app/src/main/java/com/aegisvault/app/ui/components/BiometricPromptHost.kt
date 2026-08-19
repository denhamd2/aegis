package com.aegisvault.app.ui.components

import androidx.biometric.BiometricPrompt
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * Launches BiometricPrompt (BIOMETRIC_STRONG + a negative "Use PIN" button) as soon as it
 * enters composition. [onNegativeOrError] fires on ERROR_NEGATIVE_BUTTON — the trigger the
 * vault gate uses to fall back to the custom PIN screen — as well as on any other error.
 */
@Composable
fun BiometricPromptHost(
    title: String = "Unlock Vault",
    subtitle: String = "Use your fingerprint or face to continue",
    negativeButtonText: String = "Use PIN",
    onSuccess: () -> Unit,
    onNegativeOrError: (errorCode: Int) -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? FragmentActivity ?: return

    LaunchedEffect(Unit) {
        val executor = ContextCompat.getMainExecutor(activity)
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                onSuccess()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                onNegativeOrError(errorCode)
            }
        }
        val prompt = BiometricPrompt(activity, executor, callback)
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setNegativeButtonText(negativeButtonText)
            .setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()
        prompt.authenticate(promptInfo)
    }
}
