package com.aegisvault.app.ui.screens.billing

import android.app.Activity
import androidx.lifecycle.ViewModel
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.usecase.LaunchPurchaseFlowUseCase
import com.aegisvault.app.domain.usecase.ObservePurchaseStateUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val launchPurchaseFlowUseCase: LaunchPurchaseFlowUseCase,
    observePurchaseStateUseCase: ObservePurchaseStateUseCase,
) : ViewModel() {

    val purchaseState: StateFlow<PurchaseState> = observePurchaseStateUseCase()

    fun launchPurchase(activity: Activity) = launchPurchaseFlowUseCase(activity)
}
