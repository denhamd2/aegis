package com.aegisvault.app.domain.repository

import com.aegisvault.app.domain.model.PinValidationResult

interface PinCredentialStore {
    fun isPinConfigured(): Boolean
    fun setPin(pin: String)
    fun validatePin(pin: String): PinValidationResult
    fun clearPin()
}
