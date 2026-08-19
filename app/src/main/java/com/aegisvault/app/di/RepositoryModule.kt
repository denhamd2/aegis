package com.aegisvault.app.di

import com.aegisvault.app.data.repository.BillingRepositoryImpl
import com.aegisvault.app.data.repository.GalleryRepositoryImpl
import com.aegisvault.app.data.repository.SettingsRepositoryImpl
import com.aegisvault.app.data.repository.VaultRepositoryImpl
import com.aegisvault.app.domain.repository.BillingRepository
import com.aegisvault.app.domain.repository.GalleryRepository
import com.aegisvault.app.domain.repository.PinCredentialStore
import com.aegisvault.app.data.security.PinCredentialStoreImpl
import com.aegisvault.app.domain.repository.SettingsRepository
import com.aegisvault.app.domain.repository.VaultRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindGalleryRepository(impl: GalleryRepositoryImpl): GalleryRepository

    @Binds
    @Singleton
    abstract fun bindVaultRepository(impl: VaultRepositoryImpl): VaultRepository

    @Binds
    @Singleton
    abstract fun bindBillingRepository(impl: BillingRepositoryImpl): BillingRepository

    @Binds
    @Singleton
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository

    @Binds
    @Singleton
    abstract fun bindPinCredentialStore(impl: PinCredentialStoreImpl): PinCredentialStore
}
