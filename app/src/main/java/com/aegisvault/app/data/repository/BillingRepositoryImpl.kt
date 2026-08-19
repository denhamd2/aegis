package com.aegisvault.app.data.repository

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.aegisvault.app.data.security.PinBillingPrefs
import com.aegisvault.app.domain.model.PurchaseState
import com.aegisvault.app.domain.repository.BillingRepository
import com.aegisvault.app.util.Constants
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Owns and connects its own BillingClient (rather than receiving one via DI) since the client
 * must be constructed with `this` as its PurchasesUpdatedListener. Purchase status is cached
 * locally in EncryptedSharedPreferences and re-verified against the Play billing cache on
 * every app startup via [refreshPurchases]; this never touches the network directly — Billing
 * Library's own local purchase cache/IPC to the Play Store app is the only "connection" made.
 */
@Singleton
class BillingRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    @PinBillingPrefs private val prefs: SharedPreferences,
) : BillingRepository, PurchasesUpdatedListener {

    private companion object {
        const val KEY_PURCHASE_STATE = "purchase_state"
    }

    private val repositoryScope = CoroutineScope(SupervisorJob())

    private val _purchaseState = MutableStateFlow(cachedPurchaseState())
    override val purchaseState: StateFlow<PurchaseState> = _purchaseState.asStateFlow()

    private val billingClient: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    private fun cachedPurchaseState(): PurchaseState =
        prefs.getString(KEY_PURCHASE_STATE, null)?.let {
            runCatching { PurchaseState.valueOf(it) }.getOrNull()
        } ?: PurchaseState.FREE

    override fun startConnection() {
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    repositoryScope.launch { refreshPurchases() }
                }
            }

            override fun onBillingServiceDisconnected() {
                // Reconnect with backoff is handled by the BillingClient's own retry policy
                // for queries; a fresh explicit reconnect is attempted on next foreground.
            }
        })
    }

    override fun launchPurchaseFlow(activity: Activity) {
        repositoryScope.launch {
            val productDetailsParams = QueryProductDetailsParams.newBuilder()
                .setProductList(
                    listOf(
                        QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(Constants.PRODUCT_ID_PRO_LIFETIME)
                            .setProductType(BillingClient.ProductType.INAPP)
                            .build(),
                    ),
                )
                .build()

            val result = billingClient.queryProductDetails(productDetailsParams)
            val productDetails = result.productDetailsList?.firstOrNull() ?: return@launch

            val flowParams = com.android.billingclient.api.BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(
                    listOf(
                        com.android.billingclient.api.BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(productDetails)
                            .build(),
                    ),
                )
                .build()

            billingClient.launchBillingFlow(activity, flowParams)
        }
    }

    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: MutableList<Purchase>?) {
        if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) return
        purchases?.forEach { handlePurchase(it) }
    }

    override suspend fun refreshPurchases() {
        val result = billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
        )
        result.purchasesList.forEach { handlePurchase(it) }
        if (result.purchasesList.none { it.products.contains(Constants.PRODUCT_ID_PRO_LIFETIME) }) {
            updatePurchaseState(PurchaseState.FREE)
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (!purchase.products.contains(Constants.PRODUCT_ID_PRO_LIFETIME)) return
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return

        updatePurchaseState(PurchaseState.PRO_LIFETIME)

        if (!purchase.isAcknowledged) {
            repositoryScope.launch {
                billingClient.acknowledgePurchase(
                    com.android.billingclient.api.AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build(),
                )
            }
        }
    }

    private fun updatePurchaseState(state: PurchaseState) {
        _purchaseState.value = state
        prefs.edit { putString(KEY_PURCHASE_STATE, state.name) }
    }
}
