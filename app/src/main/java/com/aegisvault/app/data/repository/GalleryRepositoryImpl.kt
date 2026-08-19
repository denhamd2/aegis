package com.aegisvault.app.data.repository

import com.aegisvault.app.data.mediastore.MediaStoreSource
import com.aegisvault.app.domain.model.Album
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem
import com.aegisvault.app.domain.repository.GalleryRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GalleryRepositoryImpl @Inject constructor(
    private val mediaStoreSource: MediaStoreSource,
) : GalleryRepository {
    override fun observeMedia(filter: MediaFilter): Flow<List<MediaItem>> = mediaStoreSource.observeMedia(filter)
    override fun observeAlbums(): Flow<List<Album>> = mediaStoreSource.observeAlbums()
    override suspend fun getAlbumMedia(bucketId: Long): List<MediaItem> = mediaStoreSource.getAlbumMedia(bucketId)
}
