package com.aegisvault.app.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.room.migration.Migration
import com.aegisvault.app.data.local.db.dao.IntruderCaptureDao
import com.aegisvault.app.data.local.db.dao.VaultItemDao
import com.aegisvault.app.data.local.db.entity.IntruderCaptureEntity
import com.aegisvault.app.data.local.db.entity.VaultItemEntity

@Database(
    entities = [VaultItemEntity::class, IntruderCaptureEntity::class],
    version = 2,
    exportSchema = true,
)
@TypeConverters(Converters::class)
abstract class AegisDatabase : RoomDatabase() {
    abstract fun vaultItemDao(): VaultItemDao
    abstract fun intruderCaptureDao(): IntruderCaptureDao

    companion object {
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `intruder_captures` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `storageFileName` TEXT NOT NULL,
                        `capturedAtMillis` INTEGER NOT NULL
                    )
                    """.trimIndent(),
                )
            }
        }
    }
}
