package com.aegisvault.app.ui.screens.utilities.exif

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.data.exif.ExifStripper
import com.aegisvault.app.domain.usecase.StripExifUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ExifStripperUiState(
    val pickedUri: Uri? = null,
    val displayName: String = "",
    val foundTags: Map<String, String> = emptyMap(),
    val strippedUri: Uri? = null,
    val isProcessing: Boolean = false,
)

@HiltViewModel
class ExifStripperViewModel @Inject constructor(
    private val exifStripper: ExifStripper,
    private val stripExifUseCase: StripExifUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ExifStripperUiState())
    val uiState: StateFlow<ExifStripperUiState> = _uiState.asStateFlow()

    fun onImagePicked(uri: Uri, displayName: String) {
        _uiState.value = ExifStripperUiState(pickedUri = uri, displayName = displayName, isProcessing = true)
        viewModelScope.launch {
            val tags = exifStripper.readPresentTags(uri)
            _uiState.update { it.copy(foundTags = tags, isProcessing = false) }
        }
    }

    fun stripMetadata() {
        val uri = _uiState.value.pickedUri ?: return
        _uiState.update { it.copy(isProcessing = true) }
        viewModelScope.launch {
            val stripped = stripExifUseCase(uri, _uiState.value.displayName)
            _uiState.update { it.copy(strippedUri = stripped, isProcessing = false) }
        }
    }
}
