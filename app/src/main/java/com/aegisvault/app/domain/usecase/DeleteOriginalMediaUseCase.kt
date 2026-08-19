package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import javax.inject.Inject

/** Confirms deletion of the original public-storage media after the user has granted
 * the system delete-consent dialog on API 29+ (see [MoveToVaultUseCase]'s RequiresDeleteConsent path). */
class DeleteOriginalMediaUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
) {
    suspend operator fun invoke(pendingItem: VaultItem) = vaultRepository.confirmDeleteAfterConsent(pendingItem)
}
