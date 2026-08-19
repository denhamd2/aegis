package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.fakes.FakeBillingRepository
import com.aegisvault.app.fakes.FakeVaultBackupManager
import com.aegisvault.app.fakes.FakeVaultRepository
import com.aegisvault.app.util.Constants
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class ImportVaultUseCaseTest {

    private fun vaultItem(id: Long) = VaultItem(
        id = id,
        storageFileName = "vault_$id.enc",
        originalDisplayName = "file_$id.jpg",
        mimeType = "image/jpeg",
        mediaType = MediaType.IMAGE,
        sizeBytes = 10,
        dateAdded = 0L,
    )

    @Test
    fun `free tier caps the import to remaining vault capacity`() = runTest {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems((1..10).map { vaultItem(it.toLong()) })
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val backupManager = FakeVaultBackupManager()
        val useCase = ImportVaultUseCase(backupManager, vaultRepository, billingRepository)

        useCase(mockk<Uri>(), "password".toCharArray())

        assertEquals(Constants.FREE_TIER_VAULT_LIMIT - 10, backupManager.lastMaxItemsToImport)
    }

    @Test
    fun `free tier at capacity allows zero imports rather than going negative`() = runTest {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems((1..Constants.FREE_TIER_VAULT_LIMIT + 5).map { vaultItem(it.toLong()) })
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val backupManager = FakeVaultBackupManager()
        val useCase = ImportVaultUseCase(backupManager, vaultRepository, billingRepository)

        useCase(mockk<Uri>(), "password".toCharArray())

        assertEquals(0, backupManager.lastMaxItemsToImport)
    }

    @Test
    fun `pro lifetime imports without a cap`() = runTest {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems((1..10).map { vaultItem(it.toLong()) })
        val billingRepository = FakeBillingRepository(PurchaseState.PRO_LIFETIME)
        val backupManager = FakeVaultBackupManager()
        val useCase = ImportVaultUseCase(backupManager, vaultRepository, billingRepository)

        useCase(mockk<Uri>(), "password".toCharArray())

        assertEquals(Int.MAX_VALUE, backupManager.lastMaxItemsToImport)
    }
}
