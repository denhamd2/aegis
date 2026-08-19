package com.aegisvault.app.data.exif

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import com.aegisvault.app.util.Constants
import com.aegisvault.app.util.IoDispatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

private val STRIPPED_TAGS = listOf(
    ExifInterface.TAG_GPS_LATITUDE, ExifInterface.TAG_GPS_LATITUDE_REF,
    ExifInterface.TAG_GPS_LONGITUDE, ExifInterface.TAG_GPS_LONGITUDE_REF,
    ExifInterface.TAG_GPS_ALTITUDE, ExifInterface.TAG_GPS_ALTITUDE_REF,
    ExifInterface.TAG_GPS_TIMESTAMP, ExifInterface.TAG_GPS_DATESTAMP,
    ExifInterface.TAG_DATETIME, ExifInterface.TAG_DATETIME_ORIGINAL, ExifInterface.TAG_DATETIME_DIGITIZED,
    ExifInterface.TAG_MAKE, ExifInterface.TAG_MODEL,
    ExifInterface.TAG_SOFTWARE, ExifInterface.TAG_ARTIST,
    ExifInterface.TAG_USER_COMMENT,
)

/**
 * Copies a MediaStore content Uri into cacheDir/shared/ (ExifInterface needs a seekable
 * local file, not a stream) and nulls out GPS/timestamp/camera-identity tags in place.
 * The original content Uri is never touched.
 */
@Singleton
class ExifStripper @Inject constructor(
    @ApplicationContext private val context: Context,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    private val sharedDir: File by lazy {
        File(context.cacheDir, Constants.SHARED_CACHE_DIR_NAME).apply { if (!exists()) mkdirs() }
    }

    suspend fun stripToCache(sourceUri: Uri, displayName: String): Uri = withContext(ioDispatcher) {
        val extension = displayName.substringAfterLast('.', "jpg")
        val outFile = File(sharedDir, "${UUID.randomUUID()}.$extension")
        context.contentResolver.openInputStream(sourceUri)?.use { input ->
            outFile.outputStream().use { output -> input.copyTo(output) }
        } ?: error("Unable to open input stream for $sourceUri")

        val exif = ExifInterface(outFile.absolutePath)
        STRIPPED_TAGS.forEach { tag -> exif.setAttribute(tag, null) }
        exif.saveAttributes()

        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", outFile)
    }

    /** Reads the human-readable values of the tags [stripToCache] would remove, for display before stripping. */
    suspend fun readPresentTags(uri: Uri): Map<String, String> = withContext(ioDispatcher) {
        context.contentResolver.openInputStream(uri)?.use { input ->
            val exif = ExifInterface(input)
            STRIPPED_TAGS.mapNotNull { tag ->
                exif.getAttribute(tag)?.let { value -> tag to value }
            }.toMap()
        } ?: emptyMap()
    }

    fun purgeStaleCache() {
        val cutoff = System.currentTimeMillis() - Constants.STALE_CACHE_MAX_AGE_MILLIS
        sharedDir.listFiles()?.forEach { file ->
            if (file.lastModified() < cutoff) file.delete()
        }
    }
}
