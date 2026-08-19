@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.aegisvault.app.ui.gallery

import android.net.Uri
import com.aegisvault.app.data.exif.ExifStripper
import com.aegisvault.app.domain.model.MediaItem
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.usecase.CheckVaultCapacityUseCase
import com.aegisvault.app.domain.usecase.FetchMediaUseCase
import com.aegisvault.app.domain.usecase.MoveToVaultUseCase
import com.aegisvault.app.domain.usecase.StripExifUseCase
import com.aegisvault.app.fakes.FakeBillingRepository
import com.aegisvault.app.fakes.FakeGalleryRepository
import com.aegisvault.app.fakes.FakeVaultRepository
import com.aegisvault.app.ui.screens.gallery.GalleryEvent
import com.aegisvault.app.ui.screens.gallery.GalleryViewModel
import com.aegisvault.app.util.MainDispatcherRule
import io.mockk.mockkStatic
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class GalleryViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private fun mediaItem(id: Long) = MediaItem(
        id = id,
        contentUri = "content://media/external/images/media/$id",
        displayName = "photo_$id.jpg",
        mimeType = "image/jpeg",
        mediaType = MediaType.IMAGE,
        dateAdded = 0L,
        sizeBytes = 100,
    )

    private fun buildViewModel(galleryRepository: FakeGalleryRepository, vaultRepository: FakeVaultRepository): GalleryViewModel {
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val fetchMediaUseCase = FetchMediaUseCase(galleryRepository)
        val checkCapacity = CheckVaultCapacityUseCase(vaultRepository, billingRepository)
        val moveToVaultUseCase = MoveToVaultUseCase(vaultRepository, checkCapacity)
        val exifStripper = io.mockk.mockk<ExifStripper>()
        val stripExifUseCase = StripExifUseCase(exifStripper)
        return GalleryViewModel(fetchMediaUseCase, moveToVaultUseCase, stripExifUseCase)
    }

    @Test
    fun `initial state loads media from repository`() = runTest(mainDispatcherRule.testDispatcher) {
        mockkStatic(Uri::class)
        val galleryRepository = FakeGalleryRepository()
        galleryRepository.setMedia(listOf(mediaItem(1), mediaItem(2)))
        val viewModel = buildViewModel(galleryRepository, FakeVaultRepository())

        advanceUntilIdle()

        assertEquals(2, viewModel.uiState.value.mediaItems.size)
    }

    @Test
    fun `toggling selection adds and removes ids`() = runTest(mainDispatcherRule.testDispatcher) {
        mockkStatic(Uri::class)
        val galleryRepository = FakeGalleryRepository()
        val item = mediaItem(1)
        galleryRepository.setMedia(listOf(item))
        val viewModel = buildViewModel(galleryRepository, FakeVaultRepository())
        advanceUntilIdle()

        viewModel.toggleSelection(item)
        assertTrue(viewModel.uiState.value.selectedIds.contains(1L))
        assertTrue(viewModel.uiState.value.selectionModeActive)

        viewModel.toggleSelection(item)
        assertTrue(viewModel.uiState.value.selectedIds.isEmpty())
    }

    @Test
    fun `moving selection to vault emits MovedToVault event`() = runTest(mainDispatcherRule.testDispatcher) {
        mockkStatic(Uri::class)
        val parsedUri = io.mockk.mockk<Uri>()
        io.mockk.every { parsedUri.toString() } returns "content://media/1"
        io.mockk.every { Uri.parse(any()) } returns parsedUri
        val galleryRepository = FakeGalleryRepository()
        val item = mediaItem(1)
        galleryRepository.setMedia(listOf(item))
        val vaultRepository = FakeVaultRepository()
        val viewModel = buildViewModel(galleryRepository, vaultRepository)
        advanceUntilIdle()

        viewModel.toggleSelection(item)

        val firstEvent = async { viewModel.events.first() }
        viewModel.moveSelectedToVault()
        advanceUntilIdle()

        assertTrue(firstEvent.await() is GalleryEvent.MovedToVault)
    }
}
