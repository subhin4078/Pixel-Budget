package dev.pixelbudget.pixel_budget

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shortcutsChannel: MethodChannel? = null
    private var pendingAction: String? = null
    private var permissionResult: MethodChannel.Result? = null
    private var csvDocuments: CsvDocuments? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingAction = NotificationShortcuts.actionFrom(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.pixelbudget.app/info",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVersion" -> {
                    try {
                        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(
                                packageName,
                                PackageManager.PackageInfoFlags.of(0),
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        result.success(info.versionName)
                    } catch (error: Exception) {
                        result.error("version_unavailable", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        csvDocuments?.close()
        val documents = CsvDocuments(this)
        csvDocuments = documents
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.pixelbudget.app/csv_documents",
        ).setMethodCallHandler(documents)
        shortcutsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.pixelbudget.app/notification_shortcuts",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(NotificationShortcuts.status(this))
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        if (enabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            if (permissionResult != null) {
                                result.error(
                                    "permission_busy",
                                    "Notification permission request already in progress",
                                    null,
                                )
                            } else {
                                permissionResult = result
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    1010,
                                )
                            }
                        } else {
                            result.success(NotificationShortcuts.setEnabled(this, enabled))
                        }
                    }
                    "takeAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                        intent.action = Intent.ACTION_MAIN
                    }
                    "openSettings" -> {
                        val settings = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            )
                        }
                        startActivity(settings)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingAction = NotificationShortcuts.actionFrom(intent)
        if (pendingAction != null) shortcutsChannel?.invokeMethod("actionAvailable", null)
    }

    override fun onResume() {
        super.onResume()
        NotificationShortcuts.refresh(this)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        csvDocuments?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        permissionResult = null
        shortcutsChannel?.setMethodCallHandler(null)
        shortcutsChannel = null
        csvDocuments?.close()
        csvDocuments = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1010) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            permissionResult?.success(NotificationShortcuts.setEnabled(this, granted))
            permissionResult = null
        }
    }
}
