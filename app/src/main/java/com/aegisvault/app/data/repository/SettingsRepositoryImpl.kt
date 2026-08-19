package com.aegisvault.app.data.repository

import android.content.SharedPreferences
import androidx.core.content.edit
import com.aegisvault.app.data.security.SettingsPrefs
import com.aegisvault.app.domain.repository.AppIconDisguise
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
        const val KEY_LOCK_ON_SCREEN_OFF = "lock_on_screen_off"
        const val KEY_LOCK_ON_FACE_DOWN = "lock_on_face_down"
        const val KEY_INTRUDER_ALERTS = "intruder_alerts_enabled"
        const val KEY_ICON_DISGUISE = "icon_disguise"
    }

    private fun currentSettings(): AppSettings = AppSettings(
        theme = prefs.getString(KEY_THEME, AppTheme.SYSTEM.name)?.let { AppTheme.valueOf(it) } ?: AppTheme.SYSTEM,
        biometricLockEnabled = prefs.getBoolean(KEY_BIOMETRIC_LOCK, true),
        autoStripExifOnExport = prefs.getBoolean(KEY_AUTO_STRIP_EXIF, false),
        lockOnScreenOff = prefs.getBoolean(KEY_LOCK_ON_SCREEN_OFF, true),
        lockOnFaceDown = prefs.getBoolean(KEY_LOCK_ON_FACE_DOWN, false),
        intruderAlertsEnabled = prefs.getBoolean(KEY_INTRUDER_ALERTS, false),
        iconDisguise = prefs.getString(KEY_ICON_DISGUISE, AppIconDisguise.DEFAULT.name)
            ?.let { AppIconDisguise.valueOf(it) } ?: AppIconDisguise.DEFAULT,
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

    override suspend fun updateLockOnScreenOff(enabled: Boolean) {
        prefs.edit { putBoolean(KEY_LOCK_ON_SCREEN_OFF, enabled) }
    }

    override suspend fun updateLockOnFaceDown(enabled: Boolean) {
        prefs.edit { putBoolean(KEY_LOCK_ON_FACE_DOWN, enabled) }
    }

    override suspend fun updateIntruderAlertsEnabled(enabled: Boolean) {
        prefs.edit { putBoolean(KEY_INTRUDER_ALERTS, enabled) }
    }

    override suspend fun updateIconDisguise(disguise: AppIconDisguise) {
        prefs.edit { putString(KEY_ICON_DISGUISE, disguise.name) }
    }
}
