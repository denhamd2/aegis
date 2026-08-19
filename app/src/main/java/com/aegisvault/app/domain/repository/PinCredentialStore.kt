package com.aegisvault.app.domain.repository

import com.aegisvault.app.domain.model.PinValidationResult
import kotlinx.coroutines.flow.Flow

interface PinCredentialStore {
    fun isPinConfigured(): Boolean
    fun setPin(pin: String)
    fun validatePin(pin: String): PinValidationResult
    fun clearPin()

    /** Emits every time [validatePin] returns [PinValidationResult.Failure] or [PinValidationResult.LockedOut]. */
    fun observeFailures(): Flow<PinValidationResult>

    /** Whether the one-time "your vault has no cloud backup" education screen has been shown. */
    fun hasSeenVaultEducation(): Boolean
    fun markVaultEducationSeen()
}
