package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.repository.BillingRepository
import com.aegisvault.app.domain.repository.VaultRepository
import com.aegisvault.app.util.Constants
import kotlinx.coroutines.flow.first
import javax.inject.Inject

sealed interface VaultCapacityStatus {
    data object Available : VaultCapacityStatus
    data class LimitReached(val limit: Int) : VaultCapacityStatus
}

/**
 * The single authoritative gate for the free-tier vault cap. Must be called both to drive
 * UI state (upsell banners, disabled actions) and again immediately before every encrypt
 * operation in [MoveToVaultUseCase], since the UI check alone cannot close a TOCTOU gap
 * created by rapid/batched moves.
 */
class CheckVaultCapacityUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
    private val billingRepository: BillingRepository,
) {
    suspend operator fun invoke(): VaultCapacityStatus {
        if (billingRepository.purchaseState.value == PurchaseState.PRO_LIFETIME) return VaultCapacityStatus.Available
        val currentCount = vaultRepository.observeVaultCount().first()
        return if (currentCount < Constants.FREE_TIER_VAULT_LIMIT) {
            VaultCapacityStatus.Available
        } else {
            VaultCapacityStatus.LimitReached(Constants.FREE_TIER_VAULT_LIMIT)
        }
    }
}
