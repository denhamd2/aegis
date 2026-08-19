package com.aegisvault.app.ui.screens.vault

import android.net.Uri
import androidx.lifecycle.DefaultLifecycleObserver
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.data.security.AutoLockSignalSource
import com.aegisvault.app.data.security.AutoLockTrigger
import com.aegisvault.app.domain.model.PinValidationResult
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.PinCredentialStore
import com.aegisvault.app.domain.repository.SettingsRepository
import com.aegisvault.app.domain.repository.VaultRepository
import com.aegisvault.app.domain.usecase.CheckVaultCapacityUseCase
import com.aegisvault.app.domain.usecase.DecryptFileUseCase
import com.aegisvault.app.domain.usecase.DeleteVaultItemUseCase
import com.aegisvault.app.domain.usecase.ObservePurchaseStateUseCase
import com.aegisvault.app.domain.usecase.RestoreFromVaultUseCase
import com.aegisvault.app.domain.usecase.ShareVaultItemUseCase
import com.aegisvault.app.domain.usecase.BiometricAvailability
import com.aegisvault.app.domain.usecase.SetPinResult
import com.aegisvault.app.domain.usecase.SetPinUseCase
import com.aegisvault.app.domain.usecase.ValidateBiometricAvailabilityUseCase
import com.aegisvault.app.domain.usecase.ValidatePinUseCase
import com.aegisvault.app.domain.usecase.VaultCapacityStatus
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Vault unlock state and decrypted thumbnails live ONLY in this ViewModel's memory — never
 * persisted — and are wiped whenever the process moves to the background (ON_STOP), so the
 * vault always re-locks rather than staying open across a backgrounding/process-death cycle.
 */
@HiltViewModel
class VaultViewModel @Inject constructor(
    private val vaultRepository: VaultRepository,
    private val decryptFileUseCase: DecryptFileUseCase,
    private val deleteVaultItemUseCase: DeleteVaultItemUseCase,
    private val shareVaultItemUseCase: ShareVaultItemUseCase,
    private val restoreFromVaultUseCase: RestoreFromVaultUseCase,
    private val checkVaultCapacityUseCase: CheckVaultCapacityUseCase,
    private val observePurchaseStateUseCase: ObservePurchaseStateUseCase,
    private val setPinUseCase: SetPinUseCase,
    private val validatePinUseCase: ValidatePinUseCase,
    private val pinCredentialStore: PinCredentialStore,
    private val validateBiometricAvailabilityUseCase: ValidateBiometricAvailabilityUseCase,
    private val settingsRepository: SettingsRepository,
    private val autoLockSignalSource: AutoLockSignalSource,
) : ViewModel() {

    fun biometricAvailability(): BiometricAvailability = validateBiometricAvailabilityUseCase()

    private val _uiState = MutableStateFlow(VaultUiState())
    val uiState: StateFlow<VaultUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<VaultEvent>()
    val events: SharedFlow<VaultEvent> = _events

    private val lockOnBackgroundObserver = object : DefaultLifecycleObserver {
        override fun onStop(owner: LifecycleOwner) = lock()
    }

    private var autoLockJob: Job? = null

    init {
        // Guarded: ProcessLifecycleOwner requires a real Android main Looper, which plain JVM
        // unit tests don't provide. Production always has it (AndroidX Startup initializes it
        // before any ViewModel runs), so this only ever no-ops under test.
        runCatching { ProcessLifecycleOwner.get().lifecycle.addObserver(lockOnBackgroundObserver) }
        observePurchaseStateUseCase().onEach { state ->
            _uiState.update { it.copy(purchaseState = state) }
        }.launchIn(viewModelScope)
    }

    fun isPinConfigured(): Boolean = pinCredentialStore.isPinConfigured()

    fun hasSeenVaultEducation(): Boolean = pinCredentialStore.hasSeenVaultEducation()

    fun markVaultEducationSeen() = pinCredentialStore.markVaultEducationSeen()

    fun setPin(pin: String): SetPinResult = setPinUseCase(pin)

    fun validatePin(pin: String): PinValidationResult {
        val result = validatePinUseCase(pin)
        if (result is PinValidationResult.Success) unlock()
        return result
    }

    fun unlock() {
        _uiState.update { it.copy(unlocked = true) }
        loadVaultItems()
        refreshCapacity()
        startAutoLockObserving()
    }

    fun lock() {
        autoLockJob?.cancel()
        autoLockJob = null
        _uiState.value = VaultUiState()
    }

    /** Re-locks on screen-off/face-down while unlocked, per the user's Settings choices. */
    private fun startAutoLockObserving() {
        autoLockJob?.cancel()
        autoLockJob = viewModelScope.launch {
            merge(autoLockSignalSource.observeScreenOff(), autoLockSignalSource.observeFaceDown())
                .combine(settingsRepository.observeSettings()) { trigger, settings -> trigger to settings }
                .collect { (trigger, settings) ->
                    val shouldLock = when (trigger) {
                        is AutoLockTrigger.ScreenOff -> settings.lockOnScreenOff
                        is AutoLockTrigger.FaceDown -> settings.lockOnFaceDown
                    }
                    if (shouldLock) lock()
                }
        }
    }

    private fun loadVaultItems() {
        viewModelScope.launch {
            vaultRepository.observeVaultItems().collect { items ->
                _uiState.update { it.copy(items = items, isLoading = false) }
            }
        }
    }

    private fun refreshCapacity() {
        viewModelScope.launch {
            val status = checkVaultCapacityUseCase()
            _uiState.update { it.copy(vaultFull = status is VaultCapacityStatus.LimitReached) }
        }
    }

    fun ensureDecrypted(item: VaultItem) {
        if (_uiState.value.decryptedThumbnails.containsKey(item.id)) return
        viewModelScope.launch {
            val bytes = decryptFileUseCase(item)
            _uiState.update { it.copy(decryptedThumbnails = it.decryptedThumbnails + (item.id to bytes)) }
        }
    }

    fun deleteItem(item: VaultItem) {
        viewModelScope.launch {
            deleteVaultItemUseCase(item)
            _uiState.update { it.copy(decryptedThumbnails = it.decryptedThumbnails - item.id) }
            refreshCapacity()
        }
    }

    fun restoreItem(item: VaultItem, onRestored: (Uri?) -> Unit) {
        viewModelScope.launch {
            val uri = restoreFromVaultUseCase(item)
            _uiState.update { it.copy(decryptedThumbnails = it.decryptedThumbnails - item.id) }
            refreshCapacity()
            onRestored(uri)
        }
    }

    fun shareItem(item: VaultItem) {
        viewModelScope.launch {
            try {
                val uri = shareVaultItemUseCase(item)
                _events.emit(VaultEvent.ShareUri(uri, item.mimeType))
            } catch (e: Exception) {
                _events.emit(VaultEvent.Error(e.message ?: "Failed to prepare item for sharing"))
            }
        }
    }

    override fun onCleared() {
        runCatching { ProcessLifecycleOwner.get().lifecycle.removeObserver(lockOnBackgroundObserver) }
        super.onCleared()
    }
}
