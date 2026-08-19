package com.aegisvault.app.data.repository

import android.content.SharedPreferences
import androidx.core.content.edit
import com.aegisvault.app.data.security.SettingsPrefs
import com.aegisvault.app.domain.repository.AppSettings
import com.aegisvault.app.domain.repository.AppTheme
import com.aegisvault.app.domain.repository.SettingsRepository
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepositoryImpl @Inject constructor(
    @SettingsPrefs private val prefs: SharedPreferences,
) : SettingsRepository {

    private companion object {
        const val KEY_THEME = "theme"
        const val KEY_BIOMETRIC_LOCK = "biometric_lock_enabled"
        const val KEY_AUTO_STRIP_EXIF = "auto_strip_exif"
    }

    private fun currentSettings(): AppSettings = AppSettings(
        theme = prefs.getString(KEY_THEME, AppTheme.SYSTEM.name)?.let { AppTheme.valueOf(it) } ?: AppTheme.SYSTEM,
        biometricLockEnabled = prefs.getBoolean(KEY_BIOMETRIC_LOCK, true),
        autoStripExifOnExport = prefs.getBoolean(KEY_AUTO_STRIP_EXIF, false),
    )

    override fun observeSettings(): Flow<AppSettings> = callbackFlow {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> trySend(currentSettings()) }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        trySend(currentSettings())
        awaitClose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }

    override suspend fun updateTheme(theme: AppTheme) {
        prefs.edit { putString(KEY_THEME, theme.name) }
    }

    override suspend fun updateBiometricLockEnabled(enabled: Boolean) {
        prefs.edit { putBoolean(KEY_BIOMETRIC_LOCK, enabled) }
    }

    override suspend fun updateAutoStripExif(enabled: Boolean) {
        prefs.edit { putBoolean(KEY_AUTO_STRIP_EXIF, enabled) }
    }
}
