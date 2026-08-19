package com.aegisvault.app.ui.screens.utilities.storage

import android.content.Context
import android.os.Environment
import android.os.StatFs
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.repository.GalleryRepository
import com.aegisvault.app.domain.repository.VaultRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StorageUiState(
    val galleryItemCount: Int = 0,
    val galleryBytes: Long = 0,
    val vaultItemCount: Int = 0,
    val vaultBytes: Long = 0,
    val deviceFreeBytes: Long = 0,
    val deviceTotalBytes: Long = 0,
    val isLoading: Boolean = true,
)

@HiltViewModel
class StorageAnalyzerViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val galleryRepository: GalleryRepository,
    private val vaultRepository: VaultRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(StorageUiState())
    val uiState: StateFlow<StorageUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            val media = galleryRepository.observeMedia(MediaFilter.ALL).first()
            val vaultItems = vaultRepository.observeVaultItems().first()
            val statFs = StatFs(Environment.getDataDirectory().path)

            _uiState.update {
                it.copy(
                    galleryItemCount = media.size,
                    galleryBytes = media.sumOf { item -> item.sizeBytes },
                    vaultItemCount = vaultItems.size,
                    vaultBytes = vaultItems.sumOf { item -> item.sizeBytes },
                    deviceFreeBytes = statFs.availableBytes,
                    deviceTotalBytes = statFs.totalBytes,
                    isLoading = false,
                )
            }
        }
    }
}
