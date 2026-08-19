package com.aegisvault.app.ui.screens.gallery

import android.content.IntentSender
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem

data class GalleryUiState(
    val filter: MediaFilter = MediaFilter.ALL,
    val mediaItems: List<MediaItem> = emptyList(),
    val selectedIds: Set<Long> = emptySet(),
    val isLoading: Boolean = true,
    val hasMediaPermission: Boolean = false,
) {
    val selectionModeActive: Boolean get() = selectedIds.isNotEmpty()
}

sealed interface GalleryEvent {
    data class RequestDeleteConsent(val intentSender: IntentSender) : GalleryEvent
    data class CapacityExceeded(val limit: Int) : GalleryEvent
    data class MovedToVault(val count: Int) : GalleryEvent
    data class ShareUris(val uris: List<String>) : GalleryEvent
    data class Error(val message: String) : GalleryEvent
}
