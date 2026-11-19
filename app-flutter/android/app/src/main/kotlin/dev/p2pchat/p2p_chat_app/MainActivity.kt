package dev.p2pchat.p2p_chat_app

import android.Manifest
import android.app.Activity
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ext.SdkExtensions
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.NetworkInterface
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val channelName = "dev.p2pchat/platform"
    private var methodChannel: MethodChannel? = null
    private val pendingShares = mutableListOf<Map<String, Any?>>()
    private var initialSharesConsumed = false
    private val shareExecutor = Executors.newSingleThreadExecutor()
    private val shareBatchSeq = AtomicInteger(0)
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingNetworkNotify: Runnable? = null
    private var lastNetworkSnapshot: String? = null
    private var pendingLegacyWriteResult: MethodChannel.Result? = null
    private val legacyWritePermRequestCode = 4092
    private var pendingGalleryPickResult: MethodChannel.Result? = null
    private val pickGalleryRequestCode = 4093

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntentAsync(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntentAsync(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPhysicalLanInterfaces" -> {
                    result.success(discoverPhysicalLanInterfaces())
                }
                "consumeInitialShares" -> {
                    initialSharesConsumed = true
                    val batch = pendingShares.toList()
                    pendingShares.clear()
                    result.success(batch)
                }
                "hasLegacyStoragePermission" -> {
                    val granted = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                        ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestLegacyStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        pendingLegacyWriteResult?.success(false)
                        pendingLegacyWriteResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            legacyWritePermRequestCode
                        )
                    }
                }
                "getPublicDownloadsSubdir" -> {
                    val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                    result.success(File(downloads, "P2PChat").absolutePath)
                }
                "getPublicDocumentsSubdir" -> {
                    val docs = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
                    result.success(File(docs, "P2PChat").absolutePath)
                }
                "exportToPublicMediaStore" -> {
                    val sourcePath = call.argument<String>("sourcePath") ?: ""
                    val mode = call.argument<String>("mode") ?: "downloads"
                    val fileName = call.argument<String>("fileName") ?: ""
                    val yearMonth = call.argument<String>("yearMonth") ?: ""
                    Thread {
                        val exported = exportToPublicMediaStore(sourcePath, mode, fileName, yearMonth)
                        mainHandler.post { result.success(exported) }
                    }.start()
                }
                "hasAllFilesPermission" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                        ) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(granted)
                }
                "requestAllFilesPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        if (Environment.isExternalStorageManager()) {
                            result.success(true)
                        } else {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Throwable) {
                                try {
                                    startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                                    result.success(true)
                                } catch (_: Throwable) {
                                    result.success(false)
                                }
                            }
                        }
                    } else {
                        if (ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.WRITE_EXTERNAL_STORAGE
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            pendingLegacyWriteResult?.success(false)
                            pendingLegacyWriteResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                                legacyWritePermRequestCode
                            )
                        }
                    }
                }
                "exportToCustomDirectory" -> {
                    val sourcePath = call.argument<String>("sourcePath") ?: ""
                    val targetDir = call.argument<String>("targetDir") ?: ""
                    val fileName = call.argument<String>("fileName") ?: ""
                    Thread {
                        val exported = exportToCustomDirectory(sourcePath, targetDir, fileName)
                        mainHandler.post { result.success(exported) }
                    }.start()
                }
                "getDeviceModelName" -> {
                    result.success(resolveDeviceModelName())
                }
                "openDirectory" -> {
                    val path = call.argument<String>("path") ?: ""
                    result.success(openDirectoryInFiles(path))
                }
                "pickGalleryImages" -> {
                    val maxItems = call.argument<Int>("maxItems") ?: 50
                    launchGalleryPicker(maxItems, result)
                }
                "clearNativeMediaCaches" -> {
                    Thread {
                        try {
                            File(cacheDir, "shared_inbox").deleteRecursively()
                            File(cacheDir, "picked_media").deleteRecursively()
                        } catch (_: Throwable) {
                        }
                        mainHandler.post { result.success(true) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        shareExecutor.shutdown()
        super.onDestroy()
    }

    override fun onStart() {
        super.onStart()
        if (methodChannel != null) {
            registerNetworkObserver()
            scheduleNotifyNetworkChanged()
        }
    }

    override fun onStop() {
        unregisterNetworkObserver()
        super.onStop()
    }

    private fun resolveDeviceModelName(): String {
        val friendly = try {
            val globalName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)?.trim()
            } else {
                null
            }
            val btName = Settings.Secure.getString(contentResolver, "bluetooth_name")?.trim()
            globalName?.takeIf { it.isNotEmpty() } ?: btName?.takeIf { it.isNotEmpty() }
        } catch (_: Throwable) {
            null
        }
        if (!friendly.isNullOrEmpty()) {
            return friendly
        }

        val manufacturer = (Build.MANUFACTURER ?: "").trim()
        val model = (Build.MODEL ?: "").trim()
        if (model.isEmpty()) return manufacturer.ifEmpty { "Android" }
        if (manufacturer.isEmpty() || model.startsWith(manufacturer, ignoreCase = true)) {
            return model
        }
        val capMan = manufacturer.replaceFirstChar { if (it.isLowerCase()) it.uppercase() else it.toString() }
        return "$capMan $model"
    }

    private fun registerNetworkObserver() {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        if (networkCallback != null) return

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                scheduleNotifyNetworkChanged()
            }

            override fun onLost(network: Network) {
                scheduleNotifyNetworkChanged()
            }

            override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                scheduleNotifyNetworkChanged()
            }

            override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
                scheduleNotifyNetworkChanged()
            }
        }
        networkCallback = callback

        try {
            val req = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            cm.registerNetworkCallback(req, callback)
        } catch (_: Exception) {
            networkCallback = null
        }
    }

    private fun unregisterNetworkObserver() {
        pendingNetworkNotify?.let { mainHandler.removeCallbacks(it) }
        pendingNetworkNotify = null
        val cb = networkCallback ?: return
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        try {
            cm.unregisterNetworkCallback(cb)
        } catch (_: Exception) {
        } finally {
            networkCallback = null
        }
    }

    private fun scheduleNotifyNetworkChanged() {
        pendingNetworkNotify?.let { mainHandler.removeCallbacks(it) }
        val task = Runnable {
            pendingNetworkNotify = null
            notifyNetworkChanged()
        }
        pendingNetworkNotify = task
        // Debounce rapid Wi-Fi -> cellular handover events (~450ms) so cellular default route settles.
        mainHandler.postDelayed(task, 450L)
    }

    private fun computeOverallNetworkSnapshot(nics: List<Map<String, Any>>): String {
        val nicSig = nics
            .map { "${it["name"]}|${it["localIp"]}|${it["networkHandle"]}" }
            .sorted()
            .joinToString(",")
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return nicSig
        val internetNets = mutableListOf<String>()
        @Suppress("DEPRECATION")
        for (net in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(net) ?: continue
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) continue
            val lp = cm.getLinkProperties(net)
            val ifName = lp?.interfaceName ?: ""
            val ips = lp?.linkAddresses
                ?.mapNotNull { it.address.hostAddress?.substringBefore('%') }
                ?.sorted()
                ?.joinToString("+") ?: ""
            val validated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            internetNets.add("${net.networkHandle}:$ifName:$validated:$ips")
        }
        internetNets.sort()
        val activeHandle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            cm.activeNetwork?.networkHandle ?: 0L
        } else {
            0L
        }
        return "$nicSig||active=$activeHandle||${internetNets.joinToString(",")}"
    }

    private fun notifyNetworkChanged() {
        val nics = discoverPhysicalLanInterfaces()
        val snapshot = computeOverallNetworkSnapshot(nics)
        if (snapshot == lastNetworkSnapshot) {
            return
        }
        lastNetworkSnapshot = snapshot
        methodChannel?.invokeMethod("onNetworkChanged", nics)
    }

    /**
     * Discovers active Wi-Fi or Ethernet networks (`NET_CAPABILITY_NOT_VPN`) AND
     * USB tethering downstream interfaces (`rndis*`, `usb*`, `ncm*`), returning their
     * metadata so Rust can bind both TUN-bypassing LAN sockets and USB dedicated-line sockets.
     */
    private fun discoverPhysicalLanInterfaces(): List<Map<String, Any>> {
        val output = mutableListOf<Map<String, Any>>()
        val seenIps = mutableSetOf<String>()

        // 1. Discover USB Tethering downstream interfaces (`rndis0`, `usb0`, `ncm0`) which are
        // not listed as upstream Networks in ConnectivityManager.allNetworks.
        try {
            val netIfaces = NetworkInterface.getNetworkInterfaces()
            while (netIfaces != null && netIfaces.hasMoreElements()) {
                val nif = netIfaces.nextElement()
                val name = nif.name ?: continue
                val lower = name.lowercase()
                val isUsb = lower.startsWith("rndis") ||
                    lower.startsWith("usb") ||
                    lower.startsWith("ncm")
                if (!isUsb || !nif.isUp) continue

                val addrs = nif.inetAddresses
                while (addrs.hasMoreElements()) {
                    val addr = addrs.nextElement()
                    if (addr !is Inet4Address || addr.isLoopbackAddress || addr.isLinkLocalAddress) {
                        continue
                    }
                    val ipStr = addr.hostAddress ?: continue
                    if (seenIps.add(ipStr)) {
                        output.add(
                            mapOf(
                                "osIndex" to nif.index,
                                "name" to "$name (USB Tether)",
                                "localIp" to ipStr,
                                "networkHandle" to 0L
                            )
                        )
                    }
                }
            }
        } catch (_: Throwable) {
        }

        // 2. Discover upstream Wi-Fi / Ethernet physical networks via ConnectivityManager.
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return output

        @Suppress("DEPRECATION")
        val networks = cm.allNetworks

        var hasWifiOrEthernet = false
        for (network in networks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            val isPhysicalLan = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
            val isNotVpn = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            if (!isPhysicalLan || !isNotVpn) continue

            val linkProps = cm.getLinkProperties(network) ?: continue
            val ifaceName = linkProps.interfaceName ?: "wlan0"
            val handle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                network.networkHandle
            } else {
                0L
            }

            for (linkAddr in linkProps.linkAddresses) {
                val addr: InetAddress = linkAddr.address
                if (addr.isLoopbackAddress || addr.isLinkLocalAddress || addr.isMulticastAddress) {
                    continue
                }
                val ipStr = addr.hostAddress?.substringBefore('%') ?: continue
                if (seenIps.add(ipStr)) {
                    hasWifiOrEthernet = true
                    output.add(
                        mapOf(
                            "osIndex" to 0,
                            "name" to ifaceName,
                            "localIp" to ipStr,
                            "networkHandle" to handle
                        )
                    )
                }
            }
        }

        // 3. When Wi-Fi / Ethernet is absent, expose physical cellular global IPv6 addresses
        // so QUIC binds directly to hardware cellular (`android_setsocknetwork`), bypassing VPN TUNs.
        if (!hasWifiOrEthernet) {
            for (network in networks) {
                val caps = cm.getNetworkCapabilities(network) ?: continue
                val isCellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
                val isNotVpn = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                if (!isCellular || !isNotVpn) continue

                val linkProps = cm.getLinkProperties(network) ?: continue
                val ifaceName = linkProps.interfaceName ?: "rmnet0"
                val handle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    network.networkHandle
                } else {
                    0L
                }

                for (linkAddr in linkProps.linkAddresses) {
                    val addr: InetAddress = linkAddr.address
                    if (addr !is Inet6Address ||
                        addr.isLoopbackAddress ||
                        addr.isLinkLocalAddress ||
                        addr.isMulticastAddress ||
                        addr.isSiteLocalAddress
                    ) {
                        continue
                    }
                    val rawBytes = addr.address
                    // Skip IPv6 Unique Local Addresses (fc00::/7)
                    if (rawBytes.isNotEmpty() && (rawBytes[0].toInt() and 0xfe) == 0xfc) {
                        continue
                    }
                    val ipStr = addr.hostAddress?.substringBefore('%') ?: continue
                    if (seenIps.add(ipStr)) {
                        output.add(
                            mapOf(
                                "osIndex" to 0,
                                "name" to ifaceName,
                                "localIp" to ipStr,
                                "networkHandle" to handle
                            )
                        )
                    }
                }
            }
        }
        return output
    }

    private fun sanitizeFileName(raw: String?, fallback: String): String {
        val cleaned = raw
            ?.substringAfterLast('/')
            ?.substringAfterLast('\\')
            ?.replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_")
            ?.trim()
            ?.trimEnd('.')
            .orEmpty()
        if (cleaned.isEmpty() || cleaned == "." || cleaned == "..") {
            val cleanFallback = fallback.trim().trimEnd('.')
            return if (cleanFallback.isEmpty() || cleanFallback == "." || cleanFallback == "..") {
                "received_file"
            } else {
                cleanFallback
            }
        }
        return cleaned
    }

    private fun handleShareIntentAsync(intent: Intent?) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        var textExtra: String? = null
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                if (uri != null) {
                    uris.add(uri)
                } else {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (!text.isNullOrBlank()) {
                        textExtra = text
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                list?.forEach { uri -> uris.add(uri) }
            }
        }
        if (uris.isEmpty() && textExtra == null) return

        val batchSeq = shareBatchSeq.incrementAndGet()
        shareExecutor.execute {
            val batch = mutableListOf<Map<String, Any?>>()
            if (uris.isNotEmpty()) {
                val rootDir = File(cacheDir, "shared_inbox").apply { mkdirs() }
                val cutoffMs = System.currentTimeMillis() - 24L * 60L * 60L * 1000L
                rootDir.listFiles()?.forEach { child ->
                    if (child.lastModified() < cutoffMs) {
                        child.deleteRecursively()
                    }
                }
                val batchDir = File(rootDir, "${System.currentTimeMillis()}_$batchSeq").apply { mkdirs() }
                uris.forEachIndexed { idx, uri ->
                    copyUriToDirectory(
                        uri = uri,
                        targetDir = batchDir,
                        fallbackStem = "shared_${System.currentTimeMillis()}_${idx + 1}",
                        uniqueNames = true
                    )?.let { path ->
                        batch.add(mapOf("type" to "file", "value" to path))
                    }
                }
            }
            if (textExtra != null) {
                batch.add(mapOf("type" to "text", "value" to textExtra))
            }
            if (batch.isEmpty()) return@execute

            mainHandler.post {
                if (isDestroyed || isFinishing) return@post
                val channel = methodChannel
                if (initialSharesConsumed && channel != null) {
                    channel.invokeMethod("onSharedItems", batch)
                } else {
                    pendingShares.addAll(batch)
                }
            }
        }
    }

    private fun copyUriToDirectory(
        uri: Uri,
        targetDir: File,
        fallbackStem: String,
        uniqueNames: Boolean
    ): String? {
        return try {
            val rawName = resolveFileName(uri)
            val sanitizedRaw = rawName
                ?.substringAfterLast('/')
                ?.substringAfterLast('\\')
                ?.replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_")
                ?.trim()
                ?.trimEnd('.')
                .orEmpty()
            val sanitized = if (sanitizedRaw == "." || sanitizedRaw == "..") "" else sanitizedRaw
            val mimeExt = contentResolver.getType(uri)
                ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
                ?.takeIf { it.isNotBlank() }
            val fileName = when {
                sanitized.isEmpty() -> if (mimeExt != null) "$fallbackStem.$mimeExt" else fallbackStem
                !sanitized.contains('.') && mimeExt != null -> "$sanitized.$mimeExt"
                else -> sanitized
            }
            val dest = if (uniqueNames) uniquePublicFile(targetDir, fileName) else File(targetDir, fileName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            if (dest.exists() && dest.length() > 0) dest.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }

    private fun isSystemPhotoPickerAvailable(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return SdkExtensions.getExtensionVersion(Build.VERSION_CODES.R) >= 2
        }
        return false
    }

    private fun launchGalleryPicker(rawMaxItems: Int, result: MethodChannel.Result) {
        pendingGalleryPickResult?.success(emptyList<String>())
        pendingGalleryPickResult = result
        val maxItems = rawMaxItems.coerceAtLeast(1)

        if (isSystemPhotoPickerAvailable()) {
            val photoPickerIntent = Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = "image/*"
                if (maxItems >= 2) {
                    val maxAllowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        minOf(maxItems, MediaStore.getPickImagesMaxLimit()).coerceAtLeast(2)
                    } else {
                        maxItems.coerceIn(2, 50)
                    }
                    putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, maxAllowed)
                }
            }
            if (photoPickerIntent.resolveActivity(packageManager) != null) {
                try {
                    startActivityForResult(photoPickerIntent, pickGalleryRequestCode)
                    return
                } catch (_: Throwable) {
                }
            }
        }

        val getContentIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, maxItems != 1)
        }
        if (getContentIntent.resolveActivity(packageManager) != null) {
            try {
                startActivityForResult(getContentIntent, pickGalleryRequestCode)
                return
            } catch (_: Throwable) {
            }
        }

        val legacyPickIntent = Intent(
            Intent.ACTION_PICK,
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        ).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, maxItems != 1)
        }
        try {
            startActivityForResult(legacyPickIntent, pickGalleryRequestCode)
        } catch (_: Throwable) {
            pendingGalleryPickResult = null
            result.success(emptyList<String>())
        }
    }

    private fun extractPickedUris(data: Intent): List<Uri> {
        val result = mutableListOf<Uri>()
        val seen = mutableSetOf<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                val uri = clip.getItemAt(i).uri ?: continue
                if (seen.add(uri.toString())) {
                    result.add(uri)
                }
            }
        }
        val single = data.data
        if (single != null && seen.add(single.toString())) {
            result.add(single)
        }
        return result
    }

    private fun copyPickedUrisToCache(uris: List<Uri>): List<String> {
        val rootDir = File(cacheDir, "picked_media").apply { mkdirs() }
        val cutoffMs = System.currentTimeMillis() - 24L * 60L * 60L * 1000L
        rootDir.listFiles()?.forEach { child ->
            if (child.isDirectory && child.lastModified() < cutoffMs) {
                child.deleteRecursively()
            }
        }
        val batchDir = File(rootDir, "${System.currentTimeMillis()}").apply { mkdirs() }
        val output = mutableListOf<String>()
        uris.forEachIndexed { idx, uri ->
            copyUriToDirectory(
                uri = uri,
                targetDir = batchDir,
                fallbackStem = "image_${idx + 1}",
                uniqueNames = true
            )?.let { output.add(it) }
        }
        return output
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickGalleryRequestCode) {
            val pending = pendingGalleryPickResult
            pendingGalleryPickResult = null
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || data == null) {
                pending.success(emptyList<String>())
                return
            }
            val uris = extractPickedUris(data)
            if (uris.isEmpty()) {
                pending.success(emptyList<String>())
                return
            }
            Thread {
                val paths = copyPickedUrisToCache(uris)
                mainHandler.post { pending.success(paths) }
            }.start()
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun resolveFileName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) return cursor.getString(idx)
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    private fun resolveMimeType(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        if (ext.isNotEmpty()) {
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)?.let { return it }
        }
        return "application/octet-stream"
    }

    private fun uniquePublicFile(dir: File, fileName: String): File {
        val candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate
        val dot = fileName.lastIndexOf('.')
        val stem = if (dot > 0) fileName.substring(0, dot) else fileName
        val ext = if (dot > 0) fileName.substring(dot) else ""
        for (i in 1..9999) {
            val numbered = File(dir, "$stem ($i)$ext")
            if (!numbered.exists()) return numbered
        }
        return File(dir, "${System.currentTimeMillis()}_$fileName")
    }

    private fun exportToPublicMediaStore(
        sourcePath: String,
        mode: String,
        rawFileName: String,
        rawYearMonth: String
    ): String? {
        val src = File(sourcePath)
        if (!src.exists() || !src.isFile) return null
        val fileName = sanitizeFileName(rawFileName, src.name)
        val ym = rawYearMonth.trim().replace(Regex("[^0-9\\-]"), "")
        val isDocuments = mode == "documents"
        val mimeType = resolveMimeType(fileName)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val baseEnvDir = if (isDocuments) {
                Environment.DIRECTORY_DOCUMENTS
            } else {
                Environment.DIRECTORY_DOWNLOADS
            }
            val relPath = if (ym.isNotEmpty()) "$baseEnvDir/P2PChat/$ym" else "$baseEnvDir/P2PChat"
            val collection = if (isDocuments) {
                MediaStore.Files.getContentUri("external")
            } else {
                MediaStore.Downloads.EXTERNAL_CONTENT_URI
            }

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relPath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            var insertedUri: Uri? = null
            return try {
                insertedUri = contentResolver.insert(collection, values) ?: return null
                contentResolver.openOutputStream(insertedUri)?.use { out ->
                    src.inputStream().use { inp ->
                        inp.copyTo(out)
                    }
                    out.flush()
                } ?: run {
                    contentResolver.delete(insertedUri, null, null)
                    return null
                }

                val doneValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                contentResolver.update(insertedUri, doneValues, null, null)

                var resolvedPath: String? = null
                var queriedDisplayName: String? = null
                contentResolver.query(
                    insertedUri,
                    arrayOf(MediaStore.MediaColumns.DATA, MediaStore.MediaColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                        if (dataIdx >= 0) resolvedPath = cursor.getString(dataIdx)
                        val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                        if (nameIdx >= 0) queriedDisplayName = cursor.getString(nameIdx)
                    }
                }

                if (!resolvedPath.isNullOrBlank()) {
                    val exportedFile = File(resolvedPath!!)
                    if (exportedFile.exists() && exportedFile.canRead()) {
                        src.delete()
                        return resolvedPath
                    }
                }
                val actualName = sanitizeFileName(queriedDisplayName, fileName)
                val basePublicDir = Environment.getExternalStoragePublicDirectory(baseEnvDir)
                val fallbackFile = File(File(basePublicDir, relPath.removePrefix("$baseEnvDir/")), actualName)
                if (fallbackFile.exists() && fallbackFile.canRead()) {
                    src.delete()
                    return fallbackFile.absolutePath
                }
                null
            } catch (_: Throwable) {
                insertedUri?.let {
                    try {
                        contentResolver.delete(it, null, null)
                    } catch (_: Throwable) {
                    }
                }
                null
            }
        }

        // Legacy Android 7-9 (API 24-28): direct file copy when WRITE_EXTERNAL_STORAGE is granted.
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }

        return try {
            val baseDir = Environment.getExternalStoragePublicDirectory(
                if (isDocuments) Environment.DIRECTORY_DOCUMENTS else Environment.DIRECTORY_DOWNLOADS
            )
            val targetDir = if (ym.isNotEmpty()) {
                File(baseDir, "P2PChat/$ym")
            } else {
                File(baseDir, "P2PChat")
            }
            if (!targetDir.exists() && !targetDir.mkdirs()) {
                return null
            }
            val dest = uniquePublicFile(targetDir, fileName)
            src.inputStream().use { inp ->
                FileOutputStream(dest).use { out ->
                    inp.copyTo(out)
                }
            }
            MediaScannerConnection.scanFile(
                this,
                arrayOf(dest.absolutePath),
                arrayOf(mimeType),
                null
            )
            if (dest.exists() && dest.length() == src.length()) {
                src.delete()
                dest.absolutePath
            } else {
                null
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun exportToCustomDirectory(
        sourcePath: String,
        rawTargetDir: String,
        rawFileName: String
    ): String? {
        val src = File(sourcePath)
        if (!src.exists() || !src.isFile) return null
        val targetPath = rawTargetDir.trim()
        if (targetPath.isEmpty()) return null
        val fileName = sanitizeFileName(rawFileName, src.name)
        val mimeType = resolveMimeType(fileName)
        return try {
            val targetDir = File(targetPath)
            if (!targetDir.exists()) targetDir.mkdirs()
            val srcParent = src.parentFile?.canonicalFile
            if (srcParent != null && targetDir.canonicalFile == srcParent) {
                return src.absolutePath
            }
            val dest = uniquePublicFile(targetDir, fileName)
            src.inputStream().use { inp ->
                dest.outputStream().use { out ->
                    inp.copyTo(out)
                }
            }
            MediaScannerConnection.scanFile(
                this,
                arrayOf(dest.absolutePath),
                arrayOf(mimeType),
                null
            )
            if (dest.exists() && dest.length() == src.length()) {
                src.delete()
                dest.absolutePath
            } else {
                null
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun openDirectoryInFiles(rawPath: String): Boolean {
        val clean = rawPath.trim()
        if (clean.isEmpty()) return false
        try {
            File(clean).mkdirs()
        } catch (_: Throwable) {
        }
        val extRoot = Environment.getExternalStorageDirectory().absolutePath.trimEnd('/')
        if (clean.startsWith(extRoot)) {
            val rel = clean.removePrefix(extRoot).trimStart('/')
            if (rel.isNotEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    val docUri = DocumentsContract.buildDocumentUri(
                        "com.android.externalstorage.documents",
                        "primary:$rel"
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(docUri, DocumentsContract.Document.MIME_TYPE_DIR)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    return true
                } catch (_: Throwable) {
                }
            }
            if (clean.contains("/Download", ignoreCase = true)) {
                try {
                    val intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    return true
                } catch (_: Throwable) {
                }
            }
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == legacyWritePermRequestCode) {
            val result = pendingLegacyWriteResult
            pendingLegacyWriteResult = null
            if (result != null) {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                result.success(granted)
            }
        }
    }
}
