package com.aegisvault.app.ui.screens.vault

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.domain.model.PinValidationResult
import com.aegisvault.app.domain.usecase.BiometricAvailability
import com.aegisvault.app.ui.components.BiometricPromptHost
import com.aegisvault.app.ui.components.PinEntryPad

private enum class GateStage { CHECKING, BIOMETRIC, PIN_SETUP, PIN_ENTRY }

@Composable
fun VaultGateScreen(
    onUnlocked: () -> Unit,
    viewModel: VaultViewModel = hiltViewModel(LocalContext.current as ComponentActivity),
) {
    var stage by remember { mutableStateOf(GateStage.CHECKING) }
    var pinInput by remember { mutableStateOf("") }
    var pinError by remember { mutableStateOf<String?>(null) }
    var settingUpFirstPin by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        stage = when (viewModel.biometricAvailability()) {
            BiometricAvailability.AVAILABLE -> GateStage.BIOMETRIC
            else -> if (viewModel.isPinConfigured()) GateStage.PIN_ENTRY else GateStage.PIN_SETUP
        }
    }

    when (stage) {
        GateStage.CHECKING -> Unit
        GateStage.BIOMETRIC -> BiometricPromptHost(
            onSuccess = { viewModel.unlock(); onUnlocked() },
            onNegativeOrError = {
                stage = if (viewModel.isPinConfigured()) GateStage.PIN_ENTRY else GateStage.PIN_SETUP
            },
        )
        GateStage.PIN_SETUP, GateStage.PIN_ENTRY -> Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(Icons.Filled.Lock, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Text(
                text = when {
                    stage == GateStage.PIN_SETUP && settingUpFirstPin == null -> "Create a 6-digit PIN"
                    stage == GateStage.PIN_SETUP -> "Confirm your PIN"
                    else -> "Enter your PIN"
                },
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 16.dp, bottom = 24.dp),
            )
            PinEntryPad(
                pinLength = pinInput.length,
                errorMessage = pinError,
                onDigit = { digit ->
                    if (pinInput.length < 6) pinInput += digit
                    if (pinInput.length == 6) {
                        when (stage) {
                            GateStage.PIN_SETUP -> {
                                val firstEntry = settingUpFirstPin
                                if (firstEntry == null) {
                                    settingUpFirstPin = pinInput
                                    pinInput = ""
                                } else if (firstEntry == pinInput) {
                                    viewModel.setPin(pinInput)
                                    viewModel.unlock()
                                    onUnlocked()
                                } else {
                                    pinError = "PINs didn't match. Try again."
                                    settingUpFirstPin = null
                                    pinInput = ""
                                }
                            }
                            GateStage.PIN_ENTRY -> {
                                when (val result = viewModel.validatePin(pinInput)) {
                                    is PinValidationResult.Success -> onUnlocked()
                                    is PinValidationResult.Failure ->
                                        pinError = "Incorrect PIN. ${result.attemptsRemaining} attempts remaining."
                                    is PinValidationResult.LockedOut ->
                                        pinError = "Too many attempts. Try again shortly."
                                    is PinValidationResult.NoPinConfigured ->
                                        stage = GateStage.PIN_SETUP
                                }
                                pinInput = ""
                            }
                            else -> Unit
                        }
                    }
                },
                onBackspace = { if (pinInput.isNotEmpty()) pinInput = pinInput.dropLast(1) },
            )
        }
    }
}
