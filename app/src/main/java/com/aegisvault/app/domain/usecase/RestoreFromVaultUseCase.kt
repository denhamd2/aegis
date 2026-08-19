package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import javax.inject.Inject

/** Decrypts [item] and writes it back to public storage (MediaStore), removing it from the vault. */
class RestoreFromVaultUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
) {
    suspend operator fun invoke(item: VaultItem): Uri? = vaultRepository.restoreToPublicStorage(item)
}
