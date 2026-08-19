package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.repository.BillingRepository
import com.aegisvault.app.domain.repository.ImportVaultResult
import com.aegisvault.app.domain.repository.VaultBackupManager
import com.aegisvault.app.domain.repository.VaultRepository
import com.aegisvault.app.util.Constants
import kotlinx.coroutines.flow.first
import javax.inject.Inject

/**
 * Owns the free-tier capacity policy for imports, mirroring [CheckVaultCapacityUseCase]:
 * Pro accounts can import everything in the archive, free accounts only fill whatever room
 * remains under [Constants.FREE_TIER_VAULT_LIMIT] rather than letting import silently exceed it.
 */
class ImportVaultUseCase @Inject constructor(
    private val vaultBackupManager: VaultBackupManager,
    private val vaultRepository: VaultRepository,
    private val billingRepository: BillingRepository,
) {
    suspend operator fun invoke(source: Uri, password: CharArray): ImportVaultResult {
        val maxItemsToImport = if (billingRepository.purchaseState.value == PurchaseState.PRO_LIFETIME) {
            Int.MAX_VALUE
        } else {
            val currentCount = vaultRepository.observeVaultCount().first()
            (Constants.FREE_TIER_VAULT_LIMIT - currentCount).coerceAtLeast(0)
        }
        return vaultBackupManager.importVault(source, password, maxItemsToImport)
    }
}
