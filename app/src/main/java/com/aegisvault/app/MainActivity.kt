package com.aegisvault.app

import android.content.IntentSender
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import com.aegisvault.app.ui.navigation.AegisNavHost
import com.aegisvault.app.ui.theme.AegisTheme
import dagger.hilt.android.AndroidEntryPoint

/**
 * Extends FragmentActivity (not plain ComponentActivity) because androidx.biometric's
 * BiometricPrompt requires a FragmentActivity host.
 */
@AndroidEntryPoint
class MainActivity : FragmentActivity() {

    lateinit var deleteConsentLauncher: ActivityResultLauncher<IntentSenderRequest>
        private set

    private var onDeleteConsentResult: ((Boolean) -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        deleteConsentLauncher = registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
            onDeleteConsentResult?.invoke(result.resultCode == RESULT_OK)
            onDeleteConsentResult = null
        }

        setContent {
            AegisTheme {
                AegisNavHost()
            }
        }
    }

    /** Relays a MediaStore delete-consent IntentSender (API 29+) to the system picker. */
    fun requestDeleteConsent(intentSender: IntentSender, onResult: (Boolean) -> Unit) {
        onDeleteConsentResult = onResult
        deleteConsentLauncher.launch(IntentSenderRequest.Builder(intentSender).build())
    }
}
