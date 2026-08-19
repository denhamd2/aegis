@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.aegisvault.app.ui.vault

import com.aegisvault.app.data.security.AutoLockSignalSource
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.PinValidationResult
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.PinCredentialStore
import com.aegisvault.app.domain.repository.SettingsRepository
import com.aegisvault.app.domain.usecase.BiometricAvailability
import com.aegisvault.app.domain.usecase.CheckVaultCapacityUseCase
import com.aegisvault.app.domain.usecase.DecryptFileUseCase
import com.aegisvault.app.domain.usecase.DeleteVaultItemUseCase
import com.aegisvault.app.domain.usecase.ObservePurchaseStateUseCase
import com.aegisvault.app.domain.usecase.RestoreFromVaultUseCase
import com.aegisvault.app.domain.usecase.SetPinUseCase
import com.aegisvault.app.domain.usecase.ShareVaultItemUseCase
import com.aegisvault.app.domain.usecase.ValidateBiometricAvailabilityUseCase
import com.aegisvault.app.domain.usecase.ValidatePinUseCase
import com.aegisvault.app.fakes.FakeBillingRepository
import com.aegisvault.app.fakes.FakeVaultRepository
import com.aegisvault.app.ui.screens.vault.VaultViewModel
import com.aegisvault.app.domain.repository.AppSettings
import com.aegisvault.app.util.MainDispatcherRule
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class VaultViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private fun vaultItem(id: Long) = VaultItem(
        id = id,
        storageFileName = "vault_$id.enc",
        originalDisplayName = "file_$id.jpg",
        mimeType = "image/jpeg",
        mediaType = MediaType.IMAGE,
        sizeBytes = 10,
        dateAdded = 0L,
    )

    private fun buildViewModel(vaultRepository: FakeVaultRepository): VaultViewModel {
        val billingRepository = FakeBillingRepository(PurchaseState.FREE)
        val pinCredentialStore = mockk<PinCredentialStore>(relaxed = true)
        every { pinCredentialStore.validatePin("123456") } returns PinValidationResult.Success
        val biometricAvailabilityUseCase = mockk<ValidateBiometricAvailabilityUseCase>()
        every { biometricAvailabilityUseCase() } returns BiometricAvailability.NO_HARDWARE
        val settingsRepository = mockk<SettingsRepository>()
        every { settingsRepository.observeSettings() } returns flowOf(AppSettings())
        val autoLockSignalSource = mockk<AutoLockSignalSource>()
        every { autoLockSignalSource.observeScreenOff() } returns emptyFlow()
        every { autoLockSignalSource.observeFaceDown() } returns emptyFlow()

        return VaultViewModel(
            vaultRepository = vaultRepository,
            decryptFileUseCase = DecryptFileUseCase(vaultRepository),
            deleteVaultItemUseCase = DeleteVaultItemUseCase(vaultRepository),
            shareVaultItemUseCase = mockk<ShareVaultItemUseCase>(relaxed = true),
            restoreFromVaultUseCase = RestoreFromVaultUseCase(vaultRepository),
            checkVaultCapacityUseCase = CheckVaultCapacityUseCase(vaultRepository, billingRepository),
            observePurchaseStateUseCase = ObservePurchaseStateUseCase(billingRepository),
            setPinUseCase = SetPinUseCase(pinCredentialStore),
            validatePinUseCase = ValidatePinUseCase(pinCredentialStore),
            pinCredentialStore = pinCredentialStore,
            validateBiometricAvailabilityUseCase = biometricAvailabilityUseCase,
            settingsRepository = settingsRepository,
            autoLockSignalSource = autoLockSignalSource,
        )
    }

    @Test
    fun `starts locked`() = runTest(mainDispatcherRule.testDispatcher) {
        val viewModel = buildViewModel(FakeVaultRepository())
        assertFalse(viewModel.uiState.value.unlocked)
    }

    @Test
    fun `correct pin unlocks and loads items`() = runTest(mainDispatcherRule.testDispatcher) {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems(listOf(vaultItem(1)))
        val viewModel = buildViewModel(vaultRepository)

        val result = viewModel.validatePin("123456")
        advanceUntilIdle()

        assertTrue(result is PinValidationResult.Success)
        assertTrue(viewModel.uiState.value.unlocked)
        assertTrue(viewModel.uiState.value.items.size == 1)
    }

    @Test
    fun `lock clears unlocked state and decrypted cache`() = runTest(mainDispatcherRule.testDispatcher) {
        val vaultRepository = FakeVaultRepository()
        vaultRepository.setItems(listOf(vaultItem(1)))
        val viewModel = buildViewModel(vaultRepository)

        viewModel.validatePin("123456")
        advanceUntilIdle()
        assertTrue(viewModel.uiState.value.unlocked)

        viewModel.lock()

        assertFalse(viewModel.uiState.value.unlocked)
        assertTrue(viewModel.uiState.value.decryptedThumbnails.isEmpty())
    }
}
