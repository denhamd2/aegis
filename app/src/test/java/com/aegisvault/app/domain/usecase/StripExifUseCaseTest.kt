package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.data.exif.ExifStripper
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class StripExifUseCaseTest {

    @Test
    fun `delegates to ExifStripper and returns the stripped uri`() = runTest {
        val exifStripper = mockk<ExifStripper>()
        val sourceUri = mockk<Uri>()
        val strippedUri = mockk<Uri>()
        coEvery { exifStripper.stripToCache(sourceUri, "photo.jpg") } returns strippedUri

        val useCase = StripExifUseCase(exifStripper)
        val result = useCase(sourceUri, "photo.jpg")

        assertEquals(strippedUri, result)
        coVerify(exactly = 1) { exifStripper.stripToCache(sourceUri, "photo.jpg") }
    }
}
