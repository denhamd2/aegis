package com.aegisvault.app.ui.screens.security

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.domain.model.IntruderCapture
import com.aegisvault.app.domain.repository.IntruderCaptureRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class IntruderLogUiState(
    val captures: List<IntruderCapture> = emptyList(),
    val decryptedPhotos: Map<Long, ByteArray> = emptyMap(),
)

@HiltViewModel
class IntruderLogViewModel @Inject constructor(
    private val repository: IntruderCaptureRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(IntruderLogUiState())
    val uiState: StateFlow<IntruderLogUiState> = _uiState.asStateFlow()

    init {
        repository.observeAll().onEach { captures ->
            _uiState.update { it.copy(captures = captures) }
        }.launchIn(viewModelScope)
    }

    fun ensureDecrypted(capture: IntruderCapture) {
        if (_uiState.value.decryptedPhotos.containsKey(capture.id)) return
        viewModelScope.launch {
            val bytes = repository.decrypt(capture)
            _uiState.update { it.copy(decryptedPhotos = it.decryptedPhotos + (capture.id to bytes)) }
        }
    }

    fun delete(capture: IntruderCapture) {
        viewModelScope.launch { repository.delete(capture) }
    }

    fun clearAll() {
        viewModelScope.launch { repository.deleteAll() }
    }
}
