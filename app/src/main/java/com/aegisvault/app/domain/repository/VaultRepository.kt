package com.aegisvault.app.domain.repository

import android.net.Uri
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import kotlinx.coroutines.flow.Flow

sealed interface VaultWriteResult {
    /** [warning] is set when the vault copy succeeded but requesting deletion of the original
     * could not even be attempted (as opposed to the user simply declining the delete prompt). */
    data class Success(val item: VaultItem, val warning: String? = null) : VaultWriteResult
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
