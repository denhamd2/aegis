package com.aegisvault.app

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.decode.VideoFrameDecoder
import com.aegisvault.app.data.exif.ExifStripper
import com.aegisvault.app.data.security.IntruderAlertWatcher
import com.aegisvault.app.domain.repository.BillingRepository
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltAndroidApp
class AegisApplication : Application(), ImageLoaderFactory {

    @Inject lateinit var exifStripper: ExifStripper
    @Inject lateinit var billingRepository: BillingRepository
    @Inject lateinit var intruderAlertWatcher: IntruderAlertWatcher

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        applicationScope.launch { exifStripper.purgeStaleCache() }
        billingRepository.startConnection()
        intruderAlertWatcher.start(applicationScope)
    }

    /** Registers the video-frame decoder so Coil can render video thumbnails in the gallery,
     * not just images — the coil-video dependency alone doesn't wire this in automatically. */
    override fun newImageLoader(): ImageLoader =
        ImageLoader.Builder(this)
            .components { add(VideoFrameDecoder.Factory()) }
            .build()
}
