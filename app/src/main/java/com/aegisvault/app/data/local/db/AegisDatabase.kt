package com.aegisvault.app.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.aegisvault.app.data.local.db.dao.VaultItemDao
import com.aegisvault.app.data.local.db.entity.VaultItemEntity

@Database(entities = [VaultItemEntity::class], version = 1, exportSchema = true)
@TypeConverters(Converters::class)
abstract class AegisDatabase : RoomDatabase() {
    abstract fun vaultItemDao(): VaultItemDao
}
