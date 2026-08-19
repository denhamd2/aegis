package com.aegisvault.app.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.data.security.AppIconController
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.repository.AppIconDisguise
import com.aegisvault.app.domain.repository.AppSettings
import com.aegisvault.app.domain.repository.AppTheme
import com.aegisvault.app.domain.repository.SettingsRepository
import com.aegisvault.app.domain.usecase.ObservePurchaseStateUseCase
import com.aegisvault.app.domain.usecase.ObserveSettingsUseCase
import com.aegisvault.app.domain.usecase.UpdateThemeSettingUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val settings: AppSettings = AppSettings(),
    val purchaseState: PurchaseState = PurchaseState.FREE,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val observeSettingsUseCase: ObserveSettingsUseCase,
    private val updateThemeSettingUseCase: UpdateThemeSettingUseCase,
    private val observePurchaseStateUseCase: ObservePurchaseStateUseCase,
    private val appIconController: AppIconController,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        combine(observeSettingsUseCase(), observePurchaseStateUseCase()) { settings, purchaseState ->
            SettingsUiState(settings, purchaseState)
        }.onEach { _uiState.value = it }.launchIn(viewModelScope)
    }

    fun setTheme(theme: AppTheme) {
        viewModelScope.launch { updateThemeSettingUseCase(theme) }
    }

    fun setBiometricLockEnabled(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.updateBiometricLockEnabled(enabled) }
    }

    fun setAutoStripExif(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.updateAutoStripExif(enabled) }
    }

    fun setLockOnScreenOff(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.updateLockOnScreenOff(enabled) }
    }

    fun setLockOnFaceDown(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.updateLockOnFaceDown(enabled) }
    }

    fun setIntruderAlertsEnabled(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.updateIntruderAlertsEnabled(enabled) }
    }

    fun setIconDisguise(disguise: AppIconDisguise) {
        viewModelScope.launch {
            settingsRepository.updateIconDisguise(disguise)
            appIconController.setIcon(disguise)
        }
    }
}
