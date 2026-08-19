package com.aegisvault.app.ui.screens.security

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.domain.repository.ExportVaultResult
import com.aegisvault.app.domain.repository.ImportVaultResult
import com.aegisvault.app.domain.usecase.ExportVaultUseCase
import com.aegisvault.app.domain.usecase.ImportVaultUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed interface DataSafetyEvent {
    data class ExportFinished(val result: ExportVaultResult) : DataSafetyEvent
    data class ImportFinished(val result: ImportVaultResult) : DataSafetyEvent
}

data class DataSafetyUiState(
    val isExporting: Boolean = false,
    val isImporting: Boolean = false,
)

@HiltViewModel
class DataSafetyViewModel @Inject constructor(
    private val exportVaultUseCase: ExportVaultUseCase,
    private val importVaultUseCase: ImportVaultUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow(DataSafetyUiState())
    val uiState: StateFlow<DataSafetyUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<DataSafetyEvent>()
    val events: SharedFlow<DataSafetyEvent> = _events

    fun exportVault(destination: Uri, password: CharArray) {
        viewModelScope.launch {
            _uiState.update { it.copy(isExporting = true) }
            val result = exportVaultUseCase(destination, password)
            _uiState.update { it.copy(isExporting = false) }
            _events.emit(DataSafetyEvent.ExportFinished(result))
        }
    }

    fun importVault(source: Uri, password: CharArray) {
        viewModelScope.launch {
            _uiState.update { it.copy(isImporting = true) }
            val result = importVaultUseCase(source, password)
            _uiState.update { it.copy(isImporting = false) }
            _events.emit(DataSafetyEvent.ImportFinished(result))
        }
    }
}
