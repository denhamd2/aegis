package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.domain.repository.ExportVaultResult
import com.aegisvault.app.domain.repository.VaultBackupManager
import javax.inject.Inject

class ExportVaultUseCase @Inject constructor(
    private val vaultBackupManager: VaultBackupManager,
) {
    suspend operator fun invoke(destination: Uri, password: CharArray): ExportVaultResult =
        vaultBackupManager.exportVault(destination, password)
}
