package com.aegisvault.app.data.repository

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.aegisvault.app.data.local.db.dao.VaultItemDao
import com.aegisvault.app.data.local.db.entity.VaultItemEntity
import com.aegisvault.app.data.mapper.toDomain
import com.aegisvault.app.data.mapper.toEntity
import com.aegisvault.app.data.mediastore.MediaDeleteResult
import com.aegisvault.app.data.mediastore.MediaStoreDeleteHandler
import com.aegisvault.app.data.security.EncryptedFileManager
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import com.aegisvault.app.domain.repository.VaultWriteResult
import com.aegisvault.app.util.IoDispatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class VaultRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val dao: VaultItemDao,
    private val encryptedFileManager: EncryptedFileManager,
    private val deleteHandler: MediaStoreDeleteHandler,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : VaultRepository {

    override fun observeVaultItems(): Flow<List<VaultItem>> = dao.observeAll().map { list -> list.map { it.toDomain() } }

    override fun observeVaultCount(): Flow<Int> = dao.observeCount()

    override suspend fun moveToVault(
        sourceUri: Uri,
        displayName: String,
        mimeType: String,
        mediaType: MediaType,
    ): VaultWriteResult = withContext(ioDispatcher) {
        val storageFileName = "vault_${UUID.randomUUID()}.enc"
        try {
            encryptedFileManager.encryptContentUri(sourceUri, storageFileName)
        } catch (e: Exception) {
            return@withContext VaultWriteResult.Error(e.message ?: "Failed to encrypt file")
        }

        // Best-effort metadata only — a failure to read the original file's size must never
        // abort a move whose encrypted copy has already been written successfully.
        val sizeBytes = try {
            context.contentResolver.openAssetFileDescriptor(sourceUri, "r")?.use { it.length } ?: 0L
        } catch (e: Exception) {
            0L
        }

        val entity = VaultItemEntity(
            storageFileName = storageFileName,
            originalDisplayName = displayName,
            mimeType = mimeType,
            mediaType = mediaType.toEntity(),
            sizeBytes = sizeBytes,
            dateAdded = System.currentTimeMillis(),
        )
        val id = try {
            dao.insert(entity)
        } catch (e: Exception) {
            encryptedFileManager.delete(storageFileName)
            return@withContext VaultWriteResult.Error(e.message ?: "Failed to record vault item")
        }
        val vaultItem = entity.copy(id = id).toDomain()

        // The vault copy is already safely written and recorded at this point, so any failure
        // requesting deletion of the original must not be surfaced as an overall failure.
        val deleteResult = try {
            deleteHandler.requestDelete(sourceUri)
        } catch (e: Exception) {
            MediaDeleteResult.Failed(e.message ?: "Failed to request deletion of the original")
        }

        when (deleteResult) {
            is MediaDeleteResult.Deleted -> VaultWriteResult.Success(vaultItem)
            is MediaDeleteResult.ConsentRequired -> VaultWriteResult.RequiresDeleteConsent(deleteResult.intentSender, vaultItem)
            // Encrypted copy is safe even if requesting deletion of the original failed outright —
            // but that's a real, unexpected failure (not the user simply declining a prompt), so
            // it must be surfaced rather than silently look identical to a full success.
            is MediaDeleteResult.Failed ->
                VaultWriteResult.Success(vaultItem, warning = "Copied to vault, but couldn't request removal of the original: ${deleteResult.message}")
        }
    }

    override suspend fun confirmDeleteAfterConsent(pendingItem: VaultItem) {
        // The system IntentSender launched from requestDelete() performs the actual deletion
        // once the user grants consent; nothing further to do here beyond this bookkeeping hook.
    }

    override suspend fun decrypt(item: VaultItem): ByteArray = encryptedFileManager.decryptToBytes(item.storageFileName)

    override suspend fun deleteVaultItem(item: VaultItem) = withContext(ioDispatcher) {
        encryptedFileManager.delete(item.storageFileName)
        dao.deleteById(item.id)
    }

    override suspend fun restoreToPublicStorage(item: VaultItem): Uri? = withContext(ioDispatcher) {
        val bytes = encryptedFileManager.decryptToBytes(item.storageFileName)
        val collection = when (item.mediaType) {
            MediaType.IMAGE -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            MediaType.VIDEO -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }
        val relativeDir = when (item.mediaType) {
            MediaType.IMAGE -> Environment.DIRECTORY_PICTURES
            MediaType.VIDEO -> Environment.DIRECTORY_MOVIES
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, item.originalDisplayName)
            put(MediaStore.MediaColumns.MIME_TYPE, item.mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$relativeDir/AegisVault")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val resolver = context.contentResolver
        val restoredUri = resolver.insert(collection, values) ?: return@withContext null
        resolver.openOutputStream(restoredUri)?.use { it.write(bytes) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(restoredUri, values, null, null)
        }
        encryptedFileManager.delete(item.storageFileName)
        dao.deleteById(item.id)
        restoredUri
    }
}
