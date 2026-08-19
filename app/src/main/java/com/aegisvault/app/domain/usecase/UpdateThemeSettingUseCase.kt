package com.aegisvault.app.domain.usecase

import com.aegisvault.app.domain.repository.AppTheme
import com.aegisvault.app.domain.repository.SettingsRepository
import javax.inject.Inject

class UpdateThemeSettingUseCase @Inject constructor(
    private val settingsRepository: SettingsRepository,
) {
    suspend operator fun invoke(theme: AppTheme) = settingsRepository.updateTheme(theme)
}
