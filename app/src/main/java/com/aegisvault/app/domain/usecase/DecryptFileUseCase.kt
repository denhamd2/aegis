package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import javax.inject.Inject

/** Decrypts a vault item into memory only. The plaintext bytes must never be written back to disk. */
class DecryptFileUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
) {
    suspend operator fun invoke(item: VaultItem): ByteArray = vaultRepository.decrypt(item)
}
