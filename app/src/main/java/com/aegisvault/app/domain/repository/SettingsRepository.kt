package com.aegisvault.app.domain.repository

import kotlinx.coroutines.flow.Flow

enum class AppTheme { SYSTEM, LIGHT, DARK }

data class AppSettings(
    val theme: AppTheme = AppTheme.SYSTEM,
    val biometricLockEnabled: Boolean = true,
    val autoStripExifOnExport: Boolean = false,
)

interface SettingsRepository {
    fun observeSettings(): Flow<AppSettings>
    suspend fun updateTheme(theme: AppTheme)
    suspend fun updateBiometricLockEnabled(enabled: Boolean)
    suspend fun updateAutoStripExif(enabled: Boolean)
}
