package com.aegisvault.app.ui.screens.vault

import android.net.Uri
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.model.VaultItem

data class VaultUiState(
    val unlocked: Boolean = false,
    val items: List<VaultItem> = emptyList(),
    val decryptedThumbnails: Map<Long, ByteArray> = emptyMap(),
    val purchaseState: PurchaseState = PurchaseState.FREE,
    val vaultFull: Boolean = false,
    val isLoading: Boolean = true,
)

sealed interface VaultEvent {
    data class ShareUri(val uri: Uri, val mimeType: String) : VaultEvent
    data class Error(val message: String) : VaultEvent
}
