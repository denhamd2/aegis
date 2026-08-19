package com.aegisvault.app.data.local.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** A distinct security event, not a vault item — captured on a failed PIN attempt. */
@Entity(tableName = "intruder_captures")
data class IntruderCaptureEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val storageFileName: String,
    val capturedAtMillis: Long,
)
