package com.open_library.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class MainActivity : FlutterActivity() {
    private val channelName = "olib/weread_private"
    private val keyAlias = "olib_weread_mobile_session"
    private val preferencesName = "olib_weread_private"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> result.success(readSession())
                        "write" -> {
                            val value = call.argument<String>("value") ?: error("Missing session")
                            writeSession(value)
                            result.success(null)
                        }
                        "delete" -> {
                            getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                                .edit().remove("session").apply()
                            result.success(null)
                        }
                        "sha1", "sha256" -> {
                            val value = call.argument<String>("value") ?: error("Missing input")
                            val algorithm = if (call.method == "sha1") "SHA-1" else "SHA-256"
                            result.success(hex(MessageDigest.getInstance(algorithm).digest(value.toByteArray(Charsets.UTF_8))))
                        }
                        "hmacSha1" -> {
                            val key = call.argument<String>("key") ?: error("Missing key")
                            val value = call.argument<String>("value") ?: error("Missing input")
                            val mac = Mac.getInstance("HmacSHA1")
                            mac.init(SecretKeySpec(key.toByteArray(Charsets.UTF_8), "HmacSHA1"))
                            result.success(hex(mac.doFinal(value.toByteArray(Charsets.UTF_8))))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("WEREAD_PRIVATE_ERROR", error.javaClass.simpleName, null)
                }
            }
    }

    private fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }

    private fun secretKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return generator.generateKey()
    }

    private fun writeSession(value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val bytes = cipher.iv + encrypted
        getSharedPreferences(preferencesName, Context.MODE_PRIVATE).edit()
            .putString("session", Base64.encodeToString(bytes, Base64.NO_WRAP)).apply()
    }

    private fun readSession(): String? {
        val encoded = getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getString("session", null) ?: return null
        val bytes = Base64.decode(encoded, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
    }
}
