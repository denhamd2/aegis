package com.aegisvault.app.fakes

import android.app.Activity
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.repository.BillingRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class FakeBillingRepository(initialState: PurchaseState = PurchaseState.FREE) : BillingRepository {
    private val state = MutableStateFlow(initialState)
    override val purchaseState: StateFlow<PurchaseState> = state

    fun setPurchaseState(newState: PurchaseState) {
        state.value = newState
    }

    override fun startConnection() = Unit
    override fun launchPurchaseFlow(activity: Activity) = Unit
    override suspend fun refreshPurchases() = Unit
}
