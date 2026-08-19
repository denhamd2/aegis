package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.PinValidationResult
import com.aegisvault.app.domain.repository.PinCredentialStore
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

class ValidatePinUseCaseTest {

    @Test
    fun `delegates result from credential store`() {
        val store = mockk<PinCredentialStore>()
        every { store.validatePin("123456") } returns PinValidationResult.Success
        val useCase = ValidatePinUseCase(store)

        assertEquals(PinValidationResult.Success, useCase("123456"))
    }

    @Test
    fun `wrong pin surfaces remaining attempts`() {
        val store = mockk<PinCredentialStore>()
        every { store.validatePin("000000") } returns PinValidationResult.Failure(attemptsRemaining = 4)
        val useCase = ValidatePinUseCase(store)

        val result = useCase("000000")
        assertEquals(PinValidationResult.Failure(4), result)
    }
}
