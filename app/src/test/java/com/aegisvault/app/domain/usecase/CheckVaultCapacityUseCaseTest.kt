package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.fakes.FakeBillingRepository
import com.aegisvault.app.fakes.FakeVaultRepository
import com.aegisvault.app.util.Constants
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class CheckVaultCapacityUseCaseTest {

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
    fun `available when free tier under limit`() = runTest {
        val vaultRepository = FakeVaultRepository()
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val useCase = CheckVaultCapacityUseCase(vaultRepository, billingRepository)

        assertTrue(useCase() is VaultCapacityStatus.Available)
    }

    @Test
    fun `limit reached at free tier cap`() = runTest {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems((1..Constants.FREE_TIER_VAULT_LIMIT).map { vaultItem(it.toLong()) })
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val useCase = CheckVaultCapacityUseCase(vaultRepository, billingRepository)

        val status = useCase()
        assertTrue(status is VaultCapacityStatus.LimitReached)
        assertTrue((status as VaultCapacityStatus.LimitReached).limit == Constants.FREE_TIER_VAULT_LIMIT)
    }

    @Test
    fun `pro lifetime is never limited`() = runTest {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems((1..50).map { vaultItem(it.toLong()) })
        val billingRepository = FakeBillingRepository(PurchaseState.PRO_LIFETIME)
        val useCase = CheckVaultCapacityUseCase(vaultRepository, billingRepository)

        assertTrue(useCase() is VaultCapacityStatus.Available)
    }
}
