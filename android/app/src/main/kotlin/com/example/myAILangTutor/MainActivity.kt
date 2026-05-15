package com.example.myAILangTutor

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.myailangtutor/share"
    private var sharedText: String? = null
    private var sharedTitle: String? = null
    private var sharedSubject: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) {
            when (intent.type) {
                "text/plain" -> {
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    sharedTitle = intent.getStringExtra(Intent.EXTRA_TITLE)
                    sharedSubject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
                }
            }
        } else if (intent?.action == Intent.ACTION_PROCESS_TEXT && intent.type == "text/plain") {
            sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val data = mutableMapOf<String, String?>()
                    data["text"] = sharedText
                    data["title"] = sharedTitle
                    data["subject"] = sharedSubject
                    result.success(data)
                    clearSharedData()
                }
                "getSharedText" -> {
                    result.success(sharedText)
                    sharedText = null
                }
                "clearSharedData" -> {
                    clearSharedData()
                    result.success(null)
                }
                "hasSharedData" -> {
                    result.success(sharedText != null || sharedTitle != null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun clearSharedData() {
        sharedText = null
        sharedTitle = null
        sharedSubject = null
    }
}
