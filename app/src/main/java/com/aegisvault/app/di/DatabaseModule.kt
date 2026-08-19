package com.aegisvault.app.di

import android.content.Context
import androidx.room.Room
import com.aegisvault.app.data.local.db.AegisDatabase
import com.aegisvault.app.data.local.db.dao.VaultItemDao
import com.aegisvault.app.util.Constants
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AegisDatabase =
        Room.databaseBuilder(context, AegisDatabase::class.java, Constants.VAULT_DATABASE_NAME).build()

    @Provides
    fun provideVaultItemDao(database: AegisDatabase): VaultItemDao = database.vaultItemDao()
}
