package com.aegisvault.app.domain.repository

import android.net.Uri

sealed interface ExportVaultResult {
    data class Success(val itemCount: Int) : ExportVaultResult
    data class Error(val message: String) : ExportVaultResult
}

sealed interface ImportVaultResult {
    data class Success(val itemCount: Int) : ImportVaultResult
    /** Some archive items couldn't be imported because doing so would exceed the free-tier cap. */
    data class PartiallyImported(val importedCount: Int, val skippedCount: Int, val limit: Int) : ImportVaultResult
    data object WrongPassword : ImportVaultResult
    data class Error(val message: String) : ImportVaultResult
}

/**
 * Exports/imports vault content (not intruder captures or settings/PIN) to/from a local,
 * password-encrypted `.aegisvault` archive — see [com.aegisvault.app.data.backup.VaultArchiveFormat].
 * This is the only way vault data survives a device wipe or reinstall, since the on-device
 * encryption key in [com.aegisvault.app.data.security.EncryptedFileManager] is device-bound.
 */
interface VaultBackupManager {
    suspend fun exportVault(destination: Uri, password: CharArray): ExportVaultResult

    /** [maxItemsToImport] is decided by the caller (see [com.aegisvault.app.domain.usecase.ImportVaultUseCase]),
     * which owns the free-tier capacity policy; this only enforces whatever cap it's given. */
    suspend fun importVault(source: Uri, password: CharArray, maxItemsToImport: Int): ImportVaultResult
}
