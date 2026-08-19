package com.aegisvault.app.domain.repository

import android.app.Activity
import com.aegisvault.app.domain.model.PurchaseState
import kotlinx.coroutines.flow.StateFlow

interface BillingRepository {
    val purchaseState: StateFlow<PurchaseState>
    fun startConnection()
    fun launchPurchaseFlow(activity: Activity)
    suspend fun refreshPurchases()
}
