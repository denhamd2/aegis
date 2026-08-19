package com.aegisvault.app.domain.repository

import kotlinx.coroutines.flow.Flow

enum class AppTheme { SYSTEM, LIGHT, DARK }

enum class AppIconDisguise { DEFAULT, CALCULATOR, NOTES }

data class AppSettings(
    val theme: AppTheme = AppTheme.SYSTEM,
    val biometricLockEnabled: Boolean = true,
    val autoStripExifOnExport: Boolean = false,
    val lockOnScreenOff: Boolean = true,
    val lockOnFaceDown: Boolean = false,
    // Default off: capturing a photo on a wrong PIN is only acceptable with explicit opt-in.
    val intruderAlertsEnabled: Boolean = false,
    val iconDisguise: AppIconDisguise = AppIconDisguise.DEFAULT,
)

interface SettingsRepository {
    fun observeSettings(): Flow<AppSettings>
    suspend fun updateTheme(theme: AppTheme)
    suspend fun updateBiometricLockEnabled(enabled: Boolean)
    suspend fun updateAutoStripExif(enabled: Boolean)
    suspend fun updateLockOnScreenOff(enabled: Boolean)
    suspend fun updateLockOnFaceDown(enabled: Boolean)
    suspend fun updateIntruderAlertsEnabled(enabled: Boolean)
    suspend fun updateIconDisguise(disguise: AppIconDisguise)
}
