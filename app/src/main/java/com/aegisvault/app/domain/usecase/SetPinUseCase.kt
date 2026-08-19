package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.repository.PinCredentialStore
import com.aegisvault.app.util.Constants
import javax.inject.Inject

sealed interface SetPinResult {
    data object Success : SetPinResult
    data object InvalidLength : SetPinResult
}

class SetPinUseCase @Inject constructor(
    private val pinCredentialStore: PinCredentialStore,
) {
    operator fun invoke(pin: String): SetPinResult {
        if (pin.length != Constants.PIN_LENGTH || !pin.all(Char::isDigit)) return SetPinResult.InvalidLength
        pinCredentialStore.setPin(pin)
        return SetPinResult.Success
    }
}
