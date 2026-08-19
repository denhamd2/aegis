package com.aegisvault.app.util

object Constants {
    const val FREE_TIER_VAULT_LIMIT = 15
    const val VAULT_DIR_NAME = "vault"
    const val SHARED_CACHE_DIR_NAME = "shared"
    const val PIN_LENGTH = 6
    const val MAX_PIN_ATTEMPTS = 5
    const val PIN_LOCKOUT_MILLIS = 30_000L
    const val PRODUCT_ID_PRO_LIFETIME = "aegis_pro_lifetime_unlock"
    const val SETTINGS_PREFS_FILE_NAME = "aegis_settings_prefs"
    const val PIN_BILLING_PREFS_FILE_NAME = "aegis_pin_billing_prefs"
    const val VAULT_DATABASE_NAME = "aegis_vault.db"
    const val STALE_CACHE_MAX_AGE_MILLIS = 60 * 60 * 1000L // 1 hour
    const val MAX_INTRUDER_CAPTURES = 20
}
