package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.repository.BillingRepository
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

class ObservePurchaseStateUseCase @Inject constructor(
    private val billingRepository: BillingRepository,
) {
    operator fun invoke(): StateFlow<PurchaseState> = billingRepository.purchaseState
}
