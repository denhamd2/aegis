package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.data.exif.ExifStripper
import javax.inject.Inject

/**
 * Produces a de-identified copy of [sourceUri] (GPS, timestamps, camera make/model/software,
 * and artist tags removed) staged under the app cache, ready to be shared via FileProvider.
 * The original content Uri is never modified.
 */
class StripExifUseCase @Inject constructor(
    private val exifStripper: ExifStripper,
) {
    suspend operator fun invoke(sourceUri: Uri, displayName: String): Uri = exifStripper.stripToCache(sourceUri, displayName)
}
