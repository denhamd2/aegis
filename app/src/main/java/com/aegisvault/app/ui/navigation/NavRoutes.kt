package com.aegisvault.app.ui.navigation

object NavRoutes {
    const val GALLERY = "gallery"
    const val VAULT_GATE = "vault_gate"
    const val VAULT = "vault"
    const val VAULT_DETAIL = "vault_detail/{vaultItemId}"
    const val UTILITIES = "utilities"
    const val EXIF_STRIPPER = "utilities/exif"
    const val PDF_VIEWER = "utilities/pdf"
    const val STORAGE_ANALYZER = "utilities/storage"
    const val SETTINGS = "settings"
    const val PAYWALL = "paywall"

    fun vaultDetail(vaultItemId: Long) = "vault_detail/$vaultItemId"

    const val TOP_LEVEL_DESTINATIONS_START = GALLERY
}
