package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.data.security.EncryptedFileManager
import java.util.UUID
import javax.inject.Inject

/** Streams [sourceUri]'s bytes directly into a new AES-256-GCM encrypted vault file. */
class EncryptFileUseCase @Inject constructor(
    private val encryptedFileManager: EncryptedFileManager,
) {
    suspend operator fun invoke(sourceUri: Uri): String {
        val storageFileName = "vault_${UUID.randomUUID()}.enc"
        encryptedFileManager.encryptContentUri(sourceUri, storageFileName)
        return storageFileName
    }
}
