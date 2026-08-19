package com.aegisvault.app.data.security

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import com.aegisvault.app.domain.repository.AppIconDisguise
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Toggles which `activity-alias` is the app's enabled launcher entry — a purely local
 * PackageManager operation. Exactly one alias is ever enabled: the new one is enabled first,
 * then the others are disabled, so the app is never left with zero launcher entries.
 */
@Singleton
class AppIconController @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private fun aliasFor(disguise: AppIconDisguise) = ComponentName(
        context,
        "com.aegisvault.app.alias.${
            when (disguise) {
                AppIconDisguise.DEFAULT -> "AegisLauncher"
                AppIconDisguise.CALCULATOR -> "CalculatorLauncher"
                AppIconDisguise.NOTES -> "NotesLauncher"
            }
        }",
    )

    fun setIcon(disguise: AppIconDisguise) {
        val target = aliasFor(disguise)
        val packageManager = context.packageManager

        packageManager.setComponentEnabledSetting(
            target,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )

        AppIconDisguise.entries.filter { it != disguise }.forEach { other ->
            packageManager.setComponentEnabledSetting(
                aliasFor(other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
