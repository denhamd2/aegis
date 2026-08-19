package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem
import com.aegisvault.app.domain.repository.GalleryRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class FetchMediaUseCase @Inject constructor(
    private val galleryRepository: GalleryRepository,
) {
    operator fun invoke(filter: MediaFilter): Flow<List<MediaItem>> = galleryRepository.observeMedia(filter)
}
