package com.aegisvault.app.fakes

import android.net.Uri
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import com.aegisvault.app.domain.repository.VaultWriteResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class FakeVaultRepository : VaultRepository {
    private val itemsFlow = MutableStateFlow<List<VaultItem>>(emptyList())
    private var nextId = 1L
    var forcedWriteResult: VaultWriteResult? = null

    fun setItems(items: List<VaultItem>) {
        itemsFlow.value = items
    }

    override fun observeVaultItems(): StateFlow<List<VaultItem>> = itemsFlow

    override fun observeVaultCount() = kotlinx.coroutines.flow.MutableStateFlow(itemsFlow.value.size)

    override suspend fun moveToVault(
        sourceUri: Uri,
        displayName: String,
        mimeType: String,
        mediaType: MediaType,
    ): VaultWriteResult {
        forcedWriteResult?.let { return it }
        val item = VaultItem(
            id = nextId++,
            storageFileName = "vault_$nextId.enc",
            originalDisplayName = displayName,
            mimeType = mimeType,
            mediaType = mediaType,
            sizeBytes = 100,
            dateAdded = 0L,
        )
        itemsFlow.value = itemsFlow.value + item
        return VaultWriteResult.Success(item)
    }

    override suspend fun confirmDeleteAfterConsent(pendingItem: VaultItem) = Unit

    override suspend fun decrypt(item: VaultItem): ByteArray = ByteArray(0)

    override suspend fun deleteVaultItem(item: VaultItem) {
        itemsFlow.value = itemsFlow.value.filterNot { it.id == item.id }
    }

    override suspend fun restoreToPublicStorage(item: VaultItem): Uri? {
        itemsFlow.value = itemsFlow.value.filterNot { it.id == item.id }
        return null
    }
}
