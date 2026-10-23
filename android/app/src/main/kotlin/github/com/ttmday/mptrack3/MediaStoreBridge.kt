package github.com.ttmday.mptrack3

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.database.ContentObserver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.MediaStore
import android.util.Log
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * MediaStore access for the Flutter side:
 *  - "mptrack3/media_store" method channel: library query, artwork,
 *    folder creation, delete and move.
 *  - "mptrack3/media_changes" event channel: fires when audio files change.
 *
 * Writes follow scoped storage rules so the app does not need
 * MANAGE_EXTERNAL_STORAGE: on Android 11+ the system shows its own
 * confirmation dialog (createDeleteRequest / createWriteRequest); on
 * Android 10 and below the legacy file APIs are used.
 */
class MediaStoreBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "MediaStoreBridge"
        const val REQUEST_DELETE = 7311
        const val REQUEST_WRITE = 7312
        private const val PRIMARY = "external_primary"
    }

    private class PendingWrite(
        val result: MethodChannel.Result,
        val onGranted: () -> Map<String, Any?>,
    )

    private val context: Context get() = activity.applicationContext
    private val methods = MethodChannel(messenger, "mptrack3/media_store")
    private val events = EventChannel(messenger, "mptrack3/media_changes")
    private val executor: ExecutorService = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var observer: ContentObserver? = null
    private var pending: PendingWrite? = null

    /** Filled by queryLibrary: track id -> item uri / file path / volume. */
    private val uriById = HashMap<Long, Uri>()
    private val pathById = HashMap<Long, String>()
    private val volumeRoots = HashMap<String, String>()

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        unregisterObserver()
        executor.shutdown()
    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "queryLibrary" -> background(result) { queryLibrary() }
            "artwork" -> {
                val id = call.argument<Number>("id")?.toLong()
                val size = call.argument<Int>("size") ?: 512
                if (id == null) result.success(null) else background(result) { artwork(id, size) }
            }
            "createFolder" -> background(result) {
                createFolder(call.argument<String>("volume") ?: PRIMARY,
                    call.argument<String>("relativePath") ?: "")
            }
            "removeEmptyFolder" -> background(result) {
                removeEmptyFolder(call.argument<String>("volume") ?: PRIMARY,
                    call.argument<String>("relativePath") ?: "")
            }
            "delete" -> delete(ids(call), result)
            "move" -> move(
                ids(call),
                call.argument<String>("volume") ?: PRIMARY,
                call.argument<String>("relativePath") ?: "",
                result,
            )
            else -> result.notImplemented()
        }
    }

    private fun ids(call: MethodCall): List<Long> =
        call.argument<List<Number>>("ids")?.map { it.toLong() } ?: emptyList()

    private fun background(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                Log.e(TAG, "background call failed", e)
                mainHandler.post { result.error("MEDIA_STORE", e.message, null) }
            }
        }
    }


    private fun queryLibrary(): Map<String, Any?> {
        val tracks = ArrayList<Map<String, Any?>>()
        val labels = HashMap<String, String>()
        uriById.clear()
        pathById.clear()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            for (volume in MediaStore.getExternalVolumeNames(context)) {
                val collection = MediaStore.Audio.Media.getContentUri(volume)
                queryCollection(collection, volume, tracks)
            }
        } else {
            queryCollection(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, null, tracks)
        }

        for (volume in tracks.mapNotNull { it["volume"] as? String }.toSet()) {
            labels[volume] = volumeLabel(volume)
        }
        return mapOf("tracks" to tracks, "volumes" to labels)
    }

    @Suppress("DEPRECATION")
    private fun queryCollection(collection: Uri, volume: String?, out: MutableList<Map<String, Any?>>) {
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.SIZE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.Audio.Media.RELATIVE_PATH)
        }
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"

        context.contentResolver.query(collection, projection.toTypedArray(), selection, null, null)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val dataCol = c.getColumnIndex(MediaStore.Audio.Media.DATA)
            val nameCol = c.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
            val titleCol = c.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durationCol = c.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val addedCol = c.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val sizeCol = c.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val relCol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                c.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH) else -1

            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val data = if (dataCol >= 0) c.getString(dataCol) else null
                val name = (if (nameCol >= 0) c.getString(nameCol) else null)
                    ?: data?.substringAfterLast('/') ?: continue
                val relativeColumn: String? = if (relCol >= 0) c.getString(relCol) else null
                val legacy = if (relativeColumn == null || volume == null) {
                    splitLegacyPath(data) ?: continue
                } else {
                    null
                }
                val relative: String = relativeColumn ?: legacy!!.second
                val trackVolume: String = volume ?: legacy!!.first
                if (data != null && data.endsWith(relative + name)) {
                    volumeRoots[trackVolume] = data.removeSuffix(relative + name).trimEnd('/')
                }

                val uri = ContentUris.withAppendedId(collection, id)
                uriById[id] = uri
                if (data != null) pathById[id] = data

                out.add(mapOf(
                    "id" to id,
                    "uri" to uri.toString(),
                    "data" to data,
                    "volume" to trackVolume,
                    "relativePath" to relative,
                    "displayName" to name,
                    "title" to (if (titleCol >= 0) c.getString(titleCol) else null),
                    "artist" to (if (artistCol >= 0) c.getString(artistCol) else null),
                    "album" to (if (albumCol >= 0) c.getString(albumCol) else null),
                    "duration" to (if (durationCol >= 0) c.getLong(durationCol) else 0L),
                    "dateAdded" to (if (addedCol >= 0) c.getLong(addedCol) else 0L),
                    "size" to (if (sizeCol >= 0) c.getLong(sizeCol) else 0L),
                ))
            }
        }
    }

    /** "/storage/emulated/0/Music/Rock/x.mp3" -> ("external_primary", "Music/Rock/"). */
    @Suppress("DEPRECATION")
    private fun splitLegacyPath(data: String?): Pair<String, String>? {
        if (data == null) return null
        val primaryRoot = Environment.getExternalStorageDirectory().absolutePath.trimEnd('/')
        val parent = data.substringBeforeLast('/', "")
        return if (data.startsWith("$primaryRoot/")) {
            val rel = parent.removePrefix(primaryRoot).trimStart('/')
            PRIMARY to (if (rel.isEmpty()) "" else "$rel/")
        } else {
            // Secondary volumes: /storage/XXXX-XXXX/<relative>
            val parts = data.removePrefix("/storage/").split('/')
            if (parts.size < 2) return null
            val rel = parts.subList(1, parts.size - 1).joinToString("/")
            parts[0].lowercase() to (if (rel.isEmpty()) "" else "$rel/")
        }
    }

    private fun volumeLabel(volume: String): String {
        if (volume == PRIMARY) return "Interno"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val manager = context.getSystemService(Context.STORAGE_SERVICE) as? StorageManager
            manager?.storageVolumes?.forEach { v ->
                if (v.uuid?.lowercase() == volume.lowercase()) {
                    return v.getDescription(context) ?: volume
                }
            }
        }
        return volume.uppercase()
    }

    @Suppress("DEPRECATION")
    private fun volumeRoot(volume: String): File {
        volumeRoots[volume]?.let { return File(it) }
        if (volume == PRIMARY) return Environment.getExternalStorageDirectory()
        return File("/storage/${volume.uppercase()}")
    }


    private fun artwork(id: Long, size: Int): ByteArray? {
        val uri = uriById[id]
            ?: ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val bitmap = context.contentResolver.loadThumbnail(uri, Size(size, size), null)
                return bitmap.toJpeg()
            } catch (_: Exception) {
                // No embedded art or no thumbnail: try the retriever below.
            }
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            val bytes = retriever.embeddedPicture ?: return null
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            var sample = 1
            while (options.outWidth / (sample * 2) >= size && options.outHeight / (sample * 2) >= size) {
                sample *= 2
            }
            if (sample == 1) return bytes
            val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sample }) ?: return bytes
            decoded.toJpeg()
        } catch (_: Exception) {
            null
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }

    private fun Bitmap.toJpeg(): ByteArray {
        val stream = ByteArrayOutputStream()
        compress(Bitmap.CompressFormat.JPEG, 90, stream)
        return stream.toByteArray()
    }


    private fun createFolder(volume: String, relativePath: String): Boolean {
        if (relativePath.isBlank()) return false
        val dir = File(volumeRoot(volume), relativePath.trim('/'))
        return try {
            dir.isDirectory || dir.mkdirs()
        } catch (e: Exception) {
            Log.w(TAG, "mkdirs failed for $dir", e)
            false
        }
    }

    private fun removeEmptyFolder(volume: String, relativePath: String): Boolean {
        if (relativePath.isBlank()) return false
        val dir = File(volumeRoot(volume), relativePath.trim('/'))
        return try {
            dir.isDirectory && (dir.list()?.isEmpty() ?: false) && dir.delete()
        } catch (e: Exception) {
            false
        }
    }


    private fun uriFor(id: Long): Uri =
        uriById[id] ?: ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)

    private fun delete(ids: List<Long>, result: MethodChannel.Result) {
        if (ids.isEmpty()) {
            result.success(mapOf("succeeded" to emptyList<Long>()))
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val request = MediaStore.createDeleteRequest(
                context.contentResolver, ids.map { uriFor(it) })
            // The system deletes the files itself once the user accepts.
            launchRequest(request.intentSender, REQUEST_DELETE, result) {
                mapOf("succeeded" to ids)
            }
            return
        }
        background(result) { legacyDelete(ids) }
    }

    private fun legacyDelete(ids: List<Long>): Map<String, Any?> {
        val ok = ArrayList<Long>()
        val failed = HashMap<String, String>()
        for (id in ids) {
            try {
                pathById[id]?.let { path ->
                    val file = File(path)
                    if (file.exists() && !file.delete()) throw IllegalStateException("cannot delete file")
                }
                context.contentResolver.delete(uriFor(id), null, null)
                ok.add(id)
            } catch (e: Exception) {
                failed[id.toString()] = e.message ?: "delete failed"
            }
        }
        return mapOf("succeeded" to ok, "failed" to failed)
    }

    private fun move(ids: List<Long>, volume: String, relativePath: String, result: MethodChannel.Result) {
        if (ids.isEmpty()) {
            result.success(mapOf("succeeded" to emptyList<Long>()))
            return
        }
        val target = relativePath.trim('/') + "/"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val request = MediaStore.createWriteRequest(
                context.contentResolver, ids.map { uriFor(it) })
            launchRequest(request.intentSender, REQUEST_WRITE, result) {
                scopedMove(ids, target)
            }
            return
        }
        background(result) { legacyMove(ids, volume, target) }
    }

    private fun scopedMove(ids: List<Long>, target: String): Map<String, Any?> {
        val ok = ArrayList<Long>()
        val failed = HashMap<String, String>()
        for (id in ids) {
            try {
                val values = ContentValues().apply {
                    put(MediaStore.Audio.Media.RELATIVE_PATH, target)
                }
                val updated = context.contentResolver.update(uriFor(id), values, null, null)
                if (updated > 0) ok.add(id) else failed[id.toString()] = "not updated"
            } catch (e: Exception) {
                failed[id.toString()] = e.message ?: "move failed"
            }
        }
        return mapOf("succeeded" to ok, "failed" to failed)
    }

    @Suppress("DEPRECATION")
    private fun legacyMove(ids: List<Long>, volume: String, target: String): Map<String, Any?> {
        val ok = ArrayList<Long>()
        val failed = HashMap<String, String>()
        val destDir = File(volumeRoot(volume), target.trim('/'))
        destDir.mkdirs()
        for (id in ids) {
            try {
                val source = File(pathById[id] ?: throw IllegalStateException("unknown file"))
                val dest = freeFile(destDir, source.name)
                if (!source.renameTo(dest)) throw IllegalStateException("cannot move file")
                // Keep the same MediaStore row (and id) by updating its path.
                val values = ContentValues().apply { put(MediaStore.Audio.Media.DATA, dest.absolutePath) }
                val updated = try {
                    context.contentResolver.update(uriFor(id), values, null, null)
                } catch (_: Exception) {
                    0
                }
                if (updated == 0) {
                    MediaScannerConnection.scanFile(context,
                        arrayOf(source.absolutePath, dest.absolutePath), null, null)
                }
                pathById[id] = dest.absolutePath
                ok.add(id)
            } catch (e: Exception) {
                failed[id.toString()] = e.message ?: "move failed"
            }
        }
        return mapOf("succeeded" to ok, "failed" to failed)
    }

    private fun freeFile(dir: File, name: String): File {
        var candidate = File(dir, name)
        val base = name.substringBeforeLast('.')
        val ext = if (name.contains('.')) "." + name.substringAfterLast('.') else ""
        var n = 1
        while (candidate.exists()) {
            candidate = File(dir, "$base ($n)$ext")
            n++
        }
        return candidate
    }


    private fun launchRequest(
        sender: android.content.IntentSender,
        requestCode: Int,
        result: MethodChannel.Result,
        onGranted: () -> Map<String, Any?>,
    ) {
        pending?.result?.success(mapOf("cancelled" to true))
        pending = PendingWrite(result, onGranted)
        try {
            activity.startIntentSenderForResult(sender, requestCode, null, 0, 0, 0)
        } catch (e: Exception) {
            pending = null
            result.error("MEDIA_STORE", e.message, null)
        }
    }

    /** Returns true when the result belonged to this bridge. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_DELETE && requestCode != REQUEST_WRITE) return false
        val request = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            request.result.success(mapOf("cancelled" to true))
            return true
        }
        background(request.result) { request.onGranted() }
        return true
    }


    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        unregisterObserver()
        val handler = Handler(Looper.getMainLooper())
        val newObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                sink?.success(1)
            }

            override fun onChange(selfChange: Boolean, uri: Uri?) {
                sink?.success(1)
            }
        }
        context.contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, true, newObserver)
        observer = newObserver
    }

    override fun onCancel(arguments: Any?) {
        unregisterObserver()
    }

    private fun unregisterObserver() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
    }
}
