package com.aegisvault.app.data.security

import com.aegisvault.app.domain.repository.IntruderCaptureRepository
import com.aegisvault.app.domain.repository.PinCredentialStore
import com.aegisvault.app.domain.repository.SettingsRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Runs for the lifetime of the process (started once from [com.aegisvault.app.AegisApplication])
 * and reacts to failed PIN attempts by capturing an on-device intruder photo, when the user has
 * opted in via Settings. Runs while the vault is locked — that's the whole point — so this is
 * intentionally not scoped to any ViewModel/screen lifecycle.
 */
@Singleton
class IntruderAlertWatcher @Inject constructor(
    private val pinCredentialStore: PinCredentialStore,
    private val settingsRepository: SettingsRepository,
    private val captureService: IntruderCaptureService,
    private val captureRepository: IntruderCaptureRepository,
) {
    fun start(scope: CoroutineScope) {
        scope.launch {
            pinCredentialStore.observeFailures().collectLatest {
                val enabled = settingsRepository.observeSettings().first().intruderAlertsEnabled
                if (!enabled) return@collectLatest
                val jpeg = captureService.captureFrontCameraJpeg() ?: return@collectLatest
                captureRepository.record(jpeg)
            }
        }
    }
}
