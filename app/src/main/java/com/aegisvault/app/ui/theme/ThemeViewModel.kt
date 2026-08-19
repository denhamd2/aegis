package com.aegisvault.app.ui.theme

import androidx.lifecycle.ViewModel
import com.aegisvault.app.domain.repository.AppTheme
import com.aegisvault.app.domain.usecase.ObserveSettingsUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import javax.inject.Inject

/** Feeds the user's chosen theme (System/Light/Dark) from Settings into AegisTheme at the app root. */
@HiltViewModel
class ThemeViewModel @Inject constructor(
    observeSettingsUseCase: ObserveSettingsUseCase,
) : ViewModel() {
    val theme: StateFlow<AppTheme> = observeSettingsUseCase()
        .map { it.theme }
        .stateIn(viewModelScope, SharingStarted.Eagerly, AppTheme.SYSTEM)
}
