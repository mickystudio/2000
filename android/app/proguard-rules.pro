# ==============================================================================
# Proguard Rules for Secure Offline-First Architecture
# Prepared for Phase 1 (inactive while minifyEnabled=false, active in production)
# ==============================================================================

# Flutter Framework & Platform Channels Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugins.** { *; }

# ==============================================================================
# 1. sqflite_sqlcipher & Net SQLCipher Keep Rules
# ==============================================================================
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class net.sqlcipher.database.SQLiteDatabase { *; }
-keep class net.sqlcipher.database.SQLiteOpenHelper { *; }
-keep class net.sqlcipher.database.SQLiteCursor { *; }
-keep class net.sqlcipher.database.SQLiteProgram { *; }
-keep class net.sqlcipher.database.SQLiteStatement { *; }
-keep class net.sqlcipher.database.SQLiteQuery { *; }
-keep class com.tekartik.sqflite_sqlcipher.** { *; }
-keepclassmembers class net.sqlcipher.database.SQLiteDatabase {
    public <methods>;
    public <fields>;
}

# Preserve JNI native method signatures for SQLCipher C libraries
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==============================================================================
# 2. flutter_secure_storage & Android Keystore / Crypto Keep Rules
# ==============================================================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class androidx.security.crypto.MasterKeys { *; }
-keep class androidx.security.crypto.EncryptedSharedPreferences { *; }
-keep class androidx.security.crypto.EncryptedFile { *; }
-keep class java.security.** { *; }
-keep class javax.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ==============================================================================
# 3. local_auth & AndroidX Biometrics Keep Rules
# ==============================================================================
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-keep class androidx.biometric.BiometricPrompt { *; }
-keep class androidx.biometric.BiometricPrompt$** { *; }
-keep class androidx.biometric.BiometricManager { *; }
-keep class androidx.fragment.app.FragmentActivity { *; }
-dontwarn androidx.biometric.**
