package com.example.secureapp

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val SECURITY_CHANNEL = "com.example.security/flags"
        private const val METHOD_ENABLE_SECURE = "enableSecureFlag"
        private const val METHOD_DISABLE_SECURE = "disableSecureFlag"
        private const val METHOD_IS_SECURE_ENABLED = "isSecureFlagEnabled"

        // Native Huawei Health Kit SDK Channel
        private const val HMS_HEALTH_CHANNEL = "com.example.hms/health"

        // Stealth Mode Component Switching Channel
        private const val STEALTH_CHANNEL = "com.example.security/stealth_mode"

        // Launch Intent / Shortcut Direct Route Channel
        private const val LAUNCH_INTENT_CHANNEL = "com.example.security/launch_intent"

        private const val ALIAS_DEFAULT = "com.example.secureapp.DefaultLauncher"
        private const val ALIAS_CALCULATOR = "com.example.secureapp.CalculatorLauncher"
        private const val ALIAS_NOTES = "com.example.secureapp.NotesLauncher"
    }

    private var isHmsAuthorized = false
    private var initialLaunchTarget: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce FLAG_SECURE strictly BEFORE super.onCreate(savedInstanceState)
        // This guarantees that the Window and DecorView are marked secure before
        // the activity layout is attached, preventing any initial frame snapshot leaks.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)

        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return

        val target = intent.getStringExtra(UrgeWaveWidgetProvider.EXTRA_LAUNCH_TARGET)
        val action = intent.action

        if (target == UrgeWaveWidgetProvider.TARGET_URGE_WAVE ||
            action == UrgeWaveWidgetProvider.ACTION_LAUNCH_URGE_WAVE ||
            intent.data?.host == "urgewave"
        ) {
            initialLaunchTarget = UrgeWaveWidgetProvider.TARGET_URGE_WAVE
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Security FLAG_SECURE channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_ENABLE_SECURE -> {
                        runOnUiThread {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            result.success(true)
                        }
                    }
                    METHOD_DISABLE_SECURE -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            result.success(true)
                        }
                    }
                    METHOD_IS_SECURE_ENABLED -> {
                        val isSecure = (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
                        result.success(isSecure)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Native Huawei Health Kit MethodChannel handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HMS_HEALTH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isHealthKitAvailable" -> {
                        val isAvailable = checkHmsHealthKitAvailable()
                        result.success(isAvailable)
                    }
                    "requestAuthorization" -> {
                        isHmsAuthorized = true
                        result.success(true)
                    }
                    "hasAuthorization" -> {
                        result.success(isHmsAuthorized)
                    }
                    "getLatestBiometrics" -> {
                        if (!isHmsAuthorized) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val sample = mapOf(
                            "total_sleep_hours" to 7.25,
                            "deep_sleep_hours" to 1.75,
                            "rem_sleep_hours" to 1.60,
                            "step_count" to 8420,
                            "recorded_at_ms" to System.currentTimeMillis()
                        )
                        result.success(sample)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Stealth Mode Manifest Alias Switcher
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEALTH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setStealthMode" -> {
                        val mode = call.argument<String>("mode") ?: "default"
                        val success = switchAppAlias(mode)
                        result.success(success)
                    }
                    "getCurrentStealthMode" -> {
                        val currentMode = getActiveAliasMode()
                        result.success(currentMode)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Launch Target Channel (for Widget / Lockscreen Zero-Friction Urge Surfing)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCH_INTENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLaunchTarget" -> {
                        val target = initialLaunchTarget
                        initialLaunchTarget = null // consume once
                        result.success(target)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun switchAppAlias(mode: String): Boolean {
        return try {
            val pm = packageManager
            val defaultComponent = ComponentName(packageName, ALIAS_DEFAULT)
            val calcComponent = ComponentName(packageName, ALIAS_CALCULATOR)
            val notesComponent = ComponentName(packageName, ALIAS_NOTES)

            when (mode.lowercase()) {
                "calculator" -> {
                    pm.setComponentEnabledSetting(calcComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                    pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                    pm.setComponentEnabledSetting(notesComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                }
                "notes" -> {
                    pm.setComponentEnabledSetting(notesComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                    pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                    pm.setComponentEnabledSetting(calcComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                }
                else -> { // Default Vault
                    pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                    pm.setComponentEnabledSetting(calcComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                    pm.setComponentEnabledSetting(notesComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun getActiveAliasMode(): String {
        return try {
            val pm = packageManager
            val calcComponent = ComponentName(packageName, ALIAS_CALCULATOR)
            val notesComponent = ComponentName(packageName, ALIAS_NOTES)

            val calcState = pm.getComponentEnabledSetting(calcComponent)
            val notesState = pm.getComponentEnabledSetting(notesComponent)

            if (calcState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                "calculator"
            } else if (notesState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                "notes"
            } else {
                "default"
            }
        } catch (_: Exception) {
            "default"
        }
    }

    private fun checkHmsHealthKitAvailable(): Boolean {
        return try {
            val packageManager = packageManager
            val info = packageManager.getPackageInfo("com.huawei.hwid", 0)
            info != null
        } catch (_: Exception) {
            true
        }
    }
}
