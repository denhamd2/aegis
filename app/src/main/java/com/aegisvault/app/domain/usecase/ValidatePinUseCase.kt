package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.PinValidationResult
import com.aegisvault.app.domain.repository.PinCredentialStore
import javax.inject.Inject

class ValidatePinUseCase @Inject constructor(
    private val pinCredentialStore: PinCredentialStore,
) {
    operator fun invoke(pin: String): PinValidationResult = pinCredentialStore.validatePin(pin)
}
