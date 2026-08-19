package com.aegisvault.app

import android.app.Application
import com.aegisvault.app.data.exif.ExifStripper
import com.aegisvault.app.domain.repository.BillingRepository
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltAndroidApp
class AegisApplication : Application() {

    @Inject lateinit var exifStripper: ExifStripper
    @Inject lateinit var billingRepository: BillingRepository

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        applicationScope.launch { exifStripper.purgeStaleCache() }
        billingRepository.startConnection()
    }
}
