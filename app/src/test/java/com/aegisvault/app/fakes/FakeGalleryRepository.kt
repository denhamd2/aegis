package com.aegisvault.app.fakes

import com.aegisvault.app.domain.model.Album
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem
import com.aegisvault.app.domain.repository.GalleryRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class FakeGalleryRepository : GalleryRepository {
    private val mediaFlow = MutableStateFlow<List<MediaItem>>(emptyList())
    private val albumsFlow = MutableStateFlow<List<Album>>(emptyList())

    fun setMedia(items: List<MediaItem>) {
        mediaFlow.value = items
    }

    override fun observeMedia(filter: MediaFilter): StateFlow<List<MediaItem>> = mediaFlow
    override fun observeAlbums(): StateFlow<List<Album>> = albumsFlow
    override suspend fun getAlbumMedia(bucketId: Long): List<MediaItem> =
        mediaFlow.value.filter { it.bucketId == bucketId }
}
