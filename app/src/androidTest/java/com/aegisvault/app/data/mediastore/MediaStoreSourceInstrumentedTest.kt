package com.aegisvault.app.data.mediastore

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.util.IoDispatcherStub
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Exercises a real MediaStore.Files ContentResolver query. Requires a device/emulator with the
 * media provider running, so this cannot run in a headless sandbox without an Android SDK.
 */
@RunWith(AndroidJUnit4::class)
class MediaStoreSourceInstrumentedTest {

    @Test
    fun observeMedia_emitsAnInitialListWithoutThrowing() = runTest {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val source = MediaStoreSource(context, IoDispatcherStub.dispatcher)

        val firstEmission = source.observeMedia(MediaFilter.ALL).first()

        assertNotNull(firstEmission)
    }
}
