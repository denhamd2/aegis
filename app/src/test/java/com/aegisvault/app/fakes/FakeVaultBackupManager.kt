package com.aegisvault.app.fakes

import android.net.Uri
import com.aegisvault.app.domain.repository.ExportVaultResult
import com.aegisvault.app.domain.repository.ImportVaultResult
import com.aegisvault.app.domain.repository.VaultBackupManager

class FakeVaultBackupManager : VaultBackupManager {
    var exportResult: ExportVaultResult = ExportVaultResult.Success(itemCount = 0)
    var importResult: ImportVaultResult = ImportVaultResult.Success(itemCount = 0)
    var lastMaxItemsToImport: Int? = null

    override suspend fun exportVault(destination: Uri, password: CharArray): ExportVaultResult = exportResult

    override suspend fun importVault(source: Uri, password: CharArray, maxItemsToImport: Int): ImportVaultResult {
        lastMaxItemsToImport = maxItemsToImport
        return importResult
    }
}
