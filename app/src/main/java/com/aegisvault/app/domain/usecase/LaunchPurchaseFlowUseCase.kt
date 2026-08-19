package com.aegisvault.app.domain.usecase

import android.app.Activity
import com.aegisvault.app.domain.repository.BillingRepository
import javax.inject.Inject

class LaunchPurchaseFlowUseCase @Inject constructor(
    private val billingRepository: BillingRepository,
) {
    operator fun invoke(activity: Activity) = billingRepository.launchPurchaseFlow(activity)
}
