package com.aegisvault.app.domain.model

sealed interface PinValidationResult {
    data object Success : PinValidationResult
    data class Failure(val attemptsRemaining: Int) : PinValidationResult
    data class LockedOut(val unlockAtMillis: Long) : PinValidationResult
    data object NoPinConfigured : PinValidationResult
}
