package com.aegisvault.app.domain.repository

import android.net.Uri
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import kotlinx.coroutines.flow.Flow

sealed interface VaultWriteResult {
    data class Success(val item: VaultItem) : VaultWriteResult
    data object CapacityExceeded : VaultWriteResult
    data class RequiresDeleteConsent(val intentSender: android.content.IntentSender, val pendingItem: VaultItem) :
        VaultWriteResult
    data class Error(val message: String) : VaultWriteResult
}

interface VaultRepository {
    fun observeVaultItems(): Flow<List<VaultItem>>
    fun observeVaultCount(): Flow<Int>

    suspend fun moveToVault(sourceUri: Uri, displayName: String, mimeType: String, mediaType: MediaType): VaultWriteResult
    suspend fun confirmDeleteAfterConsent(pendingItem: VaultItem)
    suspend fun decrypt(item: VaultItem): ByteArray
    suspend fun deleteVaultItem(item: VaultItem)
    suspend fun restoreToPublicStorage(item: VaultItem): Uri?
}
