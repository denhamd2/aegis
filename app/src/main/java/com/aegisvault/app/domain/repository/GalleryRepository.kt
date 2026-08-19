package com.aegisvault.app.domain.repository

import com.aegisvault.app.domain.model.Album
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem
import kotlinx.coroutines.flow.Flow

interface GalleryRepository {
    fun observeMedia(filter: MediaFilter): Flow<List<MediaItem>>
    fun observeAlbums(): Flow<List<Album>>
    suspend fun getAlbumMedia(bucketId: Long): List<MediaItem>
}
