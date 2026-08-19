package com.aegisvault.app.data.local.db

import androidx.room.TypeConverter
import com.aegisvault.app.data.local.db.entity.MediaTypeEntity

class Converters {
    @TypeConverter
    fun fromMediaType(value: MediaTypeEntity): String = value.name

    @TypeConverter
    fun toMediaType(value: String): MediaTypeEntity = MediaTypeEntity.valueOf(value)
}
