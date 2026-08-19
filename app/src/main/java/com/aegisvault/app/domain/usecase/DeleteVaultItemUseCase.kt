package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import javax.inject.Inject

class DeleteVaultItemUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
) {
    suspend operator fun invoke(item: VaultItem) = vaultRepository.deleteVaultItem(item)
}
