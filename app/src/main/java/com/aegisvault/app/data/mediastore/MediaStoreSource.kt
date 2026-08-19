package com.aegisvault.app.data.mediastore

import android.content.ContentUris
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.aegisvault.app.domain.model.Album
import com.aegisvault.app.domain.model.MediaFilter
import com.aegisvault.app.domain.model.MediaItem
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.util.IoDispatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/** Queries device images/videos via MediaStore.Files, re-emitting on any ContentObserver change. */
@Singleton
class MediaStoreSource @Inject constructor(
    @ApplicationContext private val context: Context,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    private val projection = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.DISPLAY_NAME,
        MediaStore.Files.FileColumns.MIME_TYPE,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.Files.FileColumns.DATE_ADDED,
        MediaStore.Files.FileColumns.SIZE,
        MediaStore.Files.FileColumns.DURATION,
        MediaStore.Files.FileColumns.BUCKET_ID,
        MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME,
    )

    private val queryUri: Uri = MediaStore.Files.getContentUri("external")

    private fun selectionFor(filter: MediaFilter): Pair<String, Array<String>> {
        val imageType = MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE
        val videoType = MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
        return when (filter) {
            MediaFilter.PHOTOS -> "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?" to arrayOf(imageType.toString())
            MediaFilter.VIDEOS -> "${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?" to arrayOf(videoType.toString())
            MediaFilter.ALL, MediaFilter.ALBUMS ->
                "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?)" to arrayOf(imageType.toString(), videoType.toString())
        }
    }

    fun observeMedia(filter: MediaFilter): Flow<List<MediaItem>> = callbackFlow {
        val (selection, args) = selectionFor(filter)
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                trySend(queryMedia(selection, args))
            }
        }
        context.contentResolver.registerContentObserver(queryUri, true, observer)
        trySend(queryMedia(selection, args))
        awaitClose { context.contentResolver.unregisterContentObserver(observer) }
    }

    suspend fun getAlbumMedia(bucketId: Long): List<MediaItem> = withContext(ioDispatcher) {
        val (baseSelection, baseArgs) = selectionFor(MediaFilter.ALL)
        val selection = "$baseSelection AND ${MediaStore.Files.FileColumns.BUCKET_ID} = ?"
        queryMedia(selection, baseArgs + bucketId.toString())
    }

    fun observeAlbums(): Flow<List<Album>> = callbackFlow {
        val (selection, args) = selectionFor(MediaFilter.ALL)
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                trySend(queryAlbums(selection, args))
            }
        }
        context.contentResolver.registerContentObserver(queryUri, true, observer)
        trySend(queryAlbums(selection, args))
        awaitClose { context.contentResolver.unregisterContentObserver(observer) }
    }

    private fun queryMedia(selection: String, args: Array<String>): List<MediaItem> {
        val items = mutableListOf<MediaItem>()
        val sortOrder = "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"
        context.contentResolver.query(queryUri, projection, selection, args, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            val typeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DURATION)
            val bucketIdCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_ID)
            val bucketNameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val mediaTypeInt = cursor.getInt(typeCol)
                val mediaType = if (mediaTypeInt == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) MediaType.VIDEO else MediaType.IMAGE
                val contentUri = ContentUris.withAppendedId(queryUri, id)
                items += MediaItem(
                    id = id,
                    contentUri = contentUri.toString(),
                    displayName = cursor.getString(nameCol) ?: "",
                    mimeType = cursor.getString(mimeCol) ?: "",
                    mediaType = mediaType,
                    dateAdded = cursor.getLong(dateCol) * 1000L,
                    sizeBytes = cursor.getLong(sizeCol),
                    durationMillis = cursor.getLong(durationCol).takeIf { it > 0 },
                    bucketId = cursor.getLong(bucketIdCol),
                    bucketDisplayName = cursor.getString(bucketNameCol),
                )
            }
        }
        return items
    }

    private fun queryAlbums(selection: String, args: Array<String>): List<Album> {
        val media = queryMedia(selection, args)
        return media.groupBy { it.bucketId }
            .mapNotNull { (bucketId, items) ->
                if (bucketId == null || items.isEmpty()) return@mapNotNull null
                Album(
                    bucketId = bucketId,
                    displayName = items.first().bucketDisplayName ?: "Unknown",
                    coverContentUri = items.first().contentUri,
                    itemCount = items.size,
                )
            }
            .sortedBy { it.displayName }
    }
}
