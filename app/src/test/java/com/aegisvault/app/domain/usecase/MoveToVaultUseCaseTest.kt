package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultWriteResult
import com.aegisvault.app.fakes.FakeBillingRepository
import com.aegisvault.app.fakes.FakeVaultRepository
import com.aegisvault.app.util.Constants
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class MoveToVaultUseCaseTest {

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
    fun `stops before encrypting when capacity is already exceeded`() = runTest {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems((1..Constants.FREE_TIER_VAULT_LIMIT).map { vaultItem(it.toLong()) })
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val checkCapacity = CheckVaultCapacityUseCase(vaultRepository, billingRepository)
        val useCase = MoveToVaultUseCase(vaultRepository, checkCapacity)

        val mockUri = mockk<Uri>()
        val result = useCase(mockUri, "photo.jpg", "image/jpeg", MediaType.IMAGE)

        assertTrue(result is MoveToVaultResult.CapacityExceeded)
        // The repository's write path must never have been reached.
        assertTrue(vaultRepository.observeVaultItems().value.size == Constants.FREE_TIER_VAULT_LIMIT)
    }

    @Test
    fun `succeeds when capacity is available`() = runTest {
        val vaultRepository = FakeVaultRepository()
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val checkCapacity = CheckVaultCapacityUseCase(vaultRepository, billingRepository)
        val useCase = MoveToVaultUseCase(vaultRepository, checkCapacity)

        val mockUri = mockk<Uri>()
        every { mockUri.toString() } returns "content://media/1"
        val result = useCase(mockUri, "photo.jpg", "image/jpeg", MediaType.IMAGE)

        assertTrue(result is MoveToVaultResult.Success)
    }
}
