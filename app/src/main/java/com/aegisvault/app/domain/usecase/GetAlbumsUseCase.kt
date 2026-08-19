package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.Album
import com.aegisvault.app.domain.repository.GalleryRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class GetAlbumsUseCase @Inject constructor(
    private val galleryRepository: GalleryRepository,
) {
    operator fun invoke(): Flow<List<Album>> = galleryRepository.observeAlbums()
}
