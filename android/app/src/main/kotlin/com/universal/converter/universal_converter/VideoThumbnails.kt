// SPDX-License-Identifier: GPL-3.0-or-later

package com.universal.converter.universal_converter

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.File
import java.io.FileOutputStream

/**
 * Evenly spaced preview frames for the trim timeline. MediaMetadataRetriever
 * uses the phone's hardware decoder and seeks to keyframes, so it is far
 * faster than decoding the whole video.
 */
object VideoThumbnails {
    /** Writes [count] JPEGs of about [height] pixels into [outDir]; returns their paths. */
    fun extract(path: String, outDir: String, count: Int, height: Int): List<String> {
        val dir = File(outDir).apply { mkdirs() }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            if (durationMs <= 0L || count <= 0) return emptyList()
            val outputs = mutableListOf<String>()
            for (i in 0 until count) {
                // Centre of each slice, in microseconds.
                val timeUs = durationMs * 1000L * (2 * i + 1) / (2L * count)
                val frame = grab(retriever, timeUs, height) ?: continue
                try {
                    val file = File(dir, "thumb_$i.jpg")
                    FileOutputStream(file).use { frame.compress(Bitmap.CompressFormat.JPEG, 80, it) }
                    outputs.add(file.absolutePath)
                } finally {
                    frame.recycle()
                }
            }
            return outputs
        } finally {
            retriever.release()
        }
    }

    private fun grab(retriever: MediaMetadataRetriever, timeUs: Long, height: Int): Bitmap? {
        val option = MediaMetadataRetriever.OPTION_CLOSEST_SYNC
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Fits inside the box while keeping the aspect ratio.
            return retriever.getScaledFrameAtTime(timeUs, option, height * 4, height)
        }
        val full = retriever.getFrameAtTime(timeUs, option) ?: return null
        val width = maxOf(1, full.width * height / maxOf(1, full.height))
        val scaled = Bitmap.createScaledBitmap(full, width, height, true)
        if (scaled !== full) full.recycle()
        return scaled
    }
}
