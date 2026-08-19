package com.aegisvault.app.ui.screens.utilities.pdf

import android.graphics.Bitmap
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.domain.usecase.RenderPdfPageUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PdfViewerUiState(
    val uri: Uri? = null,
    val pageCount: Int = 0,
    val currentPageIndex: Int = 0,
    val currentPageBitmap: Bitmap? = null,
    val isLoading: Boolean = false,
    val signatureMode: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class PdfViewerViewModel @Inject constructor(
    private val renderPdfPageUseCase: RenderPdfPageUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow(PdfViewerUiState())
    val uiState: StateFlow<PdfViewerUiState> = _uiState.asStateFlow()

    fun openPdf(uri: Uri) {
        _uiState.value = PdfViewerUiState(uri = uri, isLoading = true)
        viewModelScope.launch {
            try {
                val pageCount = renderPdfPageUseCase.open(uri)
                _uiState.update { it.copy(pageCount = pageCount) }
                renderCurrentPage()
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Unable to open PDF") }
            }
        }
    }

    fun nextPage() {
        val state = _uiState.value
        if (state.currentPageIndex < state.pageCount - 1) {
            _uiState.update { it.copy(currentPageIndex = it.currentPageIndex + 1) }
            renderCurrentPage()
        }
    }

    fun previousPage() {
        val state = _uiState.value
        if (state.currentPageIndex > 0) {
            _uiState.update { it.copy(currentPageIndex = it.currentPageIndex - 1) }
            renderCurrentPage()
        }
    }

    fun toggleSignatureMode() {
        _uiState.update { it.copy(signatureMode = !it.signatureMode) }
    }

    private fun renderCurrentPage() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val bitmap = renderPdfPageUseCase.renderPage(_uiState.value.currentPageIndex)
                _uiState.update { it.copy(currentPageBitmap = bitmap, isLoading = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message ?: "Unable to render page") }
            }
        }
    }

    override fun onCleared() {
        renderPdfPageUseCase.close()
        super.onCleared()
    }
}
