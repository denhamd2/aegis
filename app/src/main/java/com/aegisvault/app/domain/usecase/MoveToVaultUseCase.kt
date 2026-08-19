package com.aegisvault.app.domain.usecase

import android.content.IntentSender
import android.net.Uri
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import com.aegisvault.app.domain.repository.VaultWriteResult
import javax.inject.Inject

sealed interface MoveToVaultResult {
    data class Success(val item: VaultItem) : MoveToVaultResult
    data class CapacityExceeded(val limit: Int) : MoveToVaultResult
    data class RequiresDeleteConsent(val intentSender: IntentSender, val pendingItem: VaultItem) : MoveToVaultResult
    data class Error(val message: String) : MoveToVaultResult
}

/**
 * Encrypts [sourceUri] into the vault and deletes the original from public storage.
 * Re-checks vault capacity right before encrypting (see [CheckVaultCapacityUseCase]) to close
 * the TOCTOU gap a UI-only check would leave open for batched/rapid moves.
 */
class MoveToVaultUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
    private val checkVaultCapacityUseCase: CheckVaultCapacityUseCase,
) {
    suspend operator fun invoke(
        sourceUri: Uri,
        displayName: String,
        mimeType: String,
        mediaType: MediaType,
    ): MoveToVaultResult {
        val capacity = checkVaultCapacityUseCase()
        if (capacity is VaultCapacityStatus.LimitReached) {
            return MoveToVaultResult.CapacityExceeded(capacity.limit)
        }
        return when (val result = vaultRepository.moveToVault(sourceUri, displayName, mimeType, mediaType)) {
            is VaultWriteResult.Success -> MoveToVaultResult.Success(result.item)
            is VaultWriteResult.CapacityExceeded ->
                MoveToVaultResult.CapacityExceeded(com.aegisvault.app.util.Constants.FREE_TIER_VAULT_LIMIT)
            is VaultWriteResult.RequiresDeleteConsent ->
                MoveToVaultResult.RequiresDeleteConsent(result.intentSender, result.pendingItem)
            is VaultWriteResult.Error -> MoveToVaultResult.Error(result.message)
        }
    }
}
