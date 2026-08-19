package com.aegisvault.app.data.local.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.aegisvault.app.data.local.db.entity.IntruderCaptureEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface IntruderCaptureDao {
    @Query("SELECT * FROM intruder_captures ORDER BY capturedAtMillis DESC")
    fun observeAll(): Flow<List<IntruderCaptureEntity>>

    @Query("SELECT * FROM intruder_captures ORDER BY capturedAtMillis DESC")
    suspend fun getAll(): List<IntruderCaptureEntity>

    @Query("SELECT COUNT(*) FROM intruder_captures")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(capture: IntruderCaptureEntity): Long

    @Query("DELETE FROM intruder_captures WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM intruder_captures")
    suspend fun deleteAll()

    // Used to enforce a retention cap — oldest captures beyond the cap are pruned.
    @Query("SELECT * FROM intruder_captures ORDER BY capturedAtMillis DESC LIMIT -1 OFFSET :keep")
    suspend fun beyond(keep: Int): List<IntruderCaptureEntity>
}
