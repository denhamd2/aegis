package com.aegisvault.app.data.mediastore

import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.Context
import android.content.IntentSender
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

sealed interface MediaDeleteResult {
    data object Deleted : MediaDeleteResult
    data class ConsentRequired(val intentSender: IntentSender) : MediaDeleteResult
    data class Failed(val message: String) : MediaDeleteResult
}

/**
 * Deletes an original MediaStore item after it has been copied into the vault.
 * API 30+: MediaStore.createDeleteRequest returns a consent IntentSender.
 * API 29: ContentResolver.delete can throw RecoverableSecurityException carrying the same
 *         kind of IntentSender.
 * API 26-28: pre-scoped-storage, a direct ContentResolver.delete succeeds outright, backed
 *            by the app's maxSdkVersion=28 WRITE_EXTERNAL_STORAGE permission.
 */
@Singleton
class MediaStoreDeleteHandler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    fun requestDelete(contentUri: Uri): MediaDeleteResult {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                val pendingIntent = MediaStore.createDeleteRequest(context.contentResolver, listOf(contentUri))
                MediaDeleteResult.ConsentRequired(pendingIntent.intentSender)
            }
            Build.VERSION.SDK_INT == Build.VERSION_CODES.Q -> {
                try {
                    context.contentResolver.delete(contentUri, null, null)
                    MediaDeleteResult.Deleted
                } catch (e: RecoverableSecurityException) {
                    MediaDeleteResult.ConsentRequired(e.userAction.actionIntent.intentSender)
                } catch (e: SecurityException) {
                    MediaDeleteResult.Failed(e.message ?: "Delete permission denied")
                }
            }
            else -> {
                val rowsDeleted = context.contentResolver.delete(contentUri, null, null)
                if (rowsDeleted > 0) MediaDeleteResult.Deleted else MediaDeleteResult.Failed("No rows deleted")
            }
        }
    }

    fun contentUriFor(id: Long): Uri = ContentUris.withAppendedId(MediaStore.Files.getContentUri("external"), id)
}
