package com.aegisvault.app.data.security

import android.content.Context
import android.net.Uri
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKey
import com.aegisvault.app.util.Constants
import com.aegisvault.app.util.IoDispatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Wraps [EncryptedFile] (AES-256-GCM via AndroidKeyStore) for all vault file I/O.
 * Every file lives under filesDir/vault/, isolated from the public MediaStore surface.
 * All reads/writes are streamed so large video files never need to be buffered whole.
 */
@Singleton
class EncryptedFileManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val masterKey: MasterKey,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    private val vaultDir: File by lazy {
        File(context.filesDir, Constants.VAULT_DIR_NAME).apply { if (!exists()) mkdirs() }
    }

    private fun encryptedFileFor(storageFileName: String): EncryptedFile {
        val file = File(vaultDir, storageFileName)
        return EncryptedFile.Builder(
            context,
            file,
            masterKey,
            EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB,
        ).build()
    }

    suspend fun encryptContentUri(sourceUri: Uri, storageFileName: String) = withContext(ioDispatcher) {
        val destination = File(vaultDir, storageFileName)
        if (destination.exists()) destination.delete()
        val encryptedFile = encryptedFileFor(storageFileName)
        context.contentResolver.openInputStream(sourceUri)?.use { input ->
            encryptedFile.openFileOutput().use { output ->
                input.copyTo(output)
            }
        } ?: error("Unable to open input stream for $sourceUri")
    }

    suspend fun decryptToBytes(storageFileName: String): ByteArray = withContext(ioDispatcher) {
        encryptedFileFor(storageFileName).openFileInput().use { it.readBytes() }
    }

    suspend fun delete(storageFileName: String) = withContext(ioDispatcher) {
        File(vaultDir, storageFileName).takeIf(File::exists)?.delete()
        Unit
    }
}
