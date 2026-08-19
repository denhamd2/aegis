package com.aegisvault.app.ui.screens.gallery

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.usecase.FetchMediaUseCase
import com.aegisvault.app.domain.usecase.MoveToVaultResult
import com.aegisvault.app.domain.usecase.MoveToVaultUseCase
import com.aegisvault.app.domain.usecase.StripExifUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class GalleryViewModel @Inject constructor(
    private val fetchMediaUseCase: FetchMediaUseCase,
    private val moveToVaultUseCase: MoveToVaultUseCase,
    private val stripExifUseCase: StripExifUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow(GalleryUiState())
    val uiState: StateFlow<GalleryUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<GalleryEvent>()
    val events: SharedFlow<GalleryEvent> = _events

    private val moveQueue = ArrayDeque<MediaItem>()
    private var movedCount = 0

    init {
        observeMedia(MediaFilter.ALL)
    }

    private fun observeMedia(filter: MediaFilter) {
        viewModelScope.launch {
            fetchMediaUseCase(filter).collectLatest { items ->
                _uiState.update { it.copy(mediaItems = items, isLoading = false, hasMediaPermission = true) }
            }
        }
    }

    fun onPermissionResult(granted: Boolean) {
        _uiState.update { it.copy(hasMediaPermission = granted, isLoading = granted) }
        if (granted) observeMedia(_uiState.value.filter)
    }

    fun setFilter(filter: MediaFilter) {
        _uiState.update { it.copy(filter = filter, isLoading = true) }
        observeMedia(filter)
    }

    fun toggleSelection(item: MediaItem) {
        _uiState.update { state ->
            val newSelection = if (state.selectedIds.contains(item.id)) {
                state.selectedIds - item.id
            } else {
                state.selectedIds + item.id
            }
            state.copy(selectedIds = newSelection)
        }
    }

    fun clearSelection() {
        _uiState.update { it.copy(selectedIds = emptySet()) }
    }

    fun moveSelectedToVault() {
        val selected = _uiState.value.mediaItems.filter { _uiState.value.selectedIds.contains(it.id) }
        if (selected.isEmpty()) return
        moveQueue.clear()
        moveQueue.addAll(selected)
        movedCount = 0
        clearSelection()
        processMoveQueue()
    }

    private fun processMoveQueue() {
        val next = moveQueue.removeFirstOrNull()
        if (next == null) {
            if (movedCount > 0) {
                viewModelScope.launch { _events.emit(GalleryEvent.MovedToVault(movedCount)) }
            }
            return
        }
        viewModelScope.launch {
            val result = moveToVaultUseCase(
                sourceUri = Uri.parse(next.contentUri),
                displayName = next.displayName,
                mimeType = next.mimeType,
                mediaType = next.mediaType,
            )
            when (result) {
                is MoveToVaultResult.Success -> {
                    movedCount++
                    processMoveQueue()
                }
                is MoveToVaultResult.RequiresDeleteConsent -> {
                    movedCount++
                    _events.emit(GalleryEvent.RequestDeleteConsent(result.intentSender))
                    // Consent IntentSender performs the actual system delete on confirmation;
                    // no need to block the rest of the queue on the user's response.
                    processMoveQueue()
                }
                is MoveToVaultResult.CapacityExceeded -> {
                    moveQueue.clear()
                    _events.emit(GalleryEvent.CapacityExceeded(result.limit))
                }
                is MoveToVaultResult.Error -> {
                    _events.emit(GalleryEvent.Error(result.message))
                    processMoveQueue()
                }
            }
        }
    }

    fun shareSelectedStripped() {
        val selected = _uiState.value.mediaItems.filter { _uiState.value.selectedIds.contains(it.id) }
        if (selected.isEmpty()) return
        clearSelection()
        viewModelScope.launch {
            val shareUris = selected.map { item ->
                if (item.mediaType == MediaType.IMAGE) {
                    stripExifUseCase(Uri.parse(item.contentUri), item.displayName).toString()
                } else {
                    item.contentUri
                }
            }
            _events.emit(GalleryEvent.ShareUris(shareUris))
        }
    }
}
