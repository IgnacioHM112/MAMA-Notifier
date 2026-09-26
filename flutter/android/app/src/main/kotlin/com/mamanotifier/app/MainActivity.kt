package com.mamanotifier.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mama_notifier/wifi_events"
    private var connectivityMgr: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerNetworkCallback()
                }
                override fun onCancel(arguments: Any?) {
                    unregisterNetworkCallback()
                    eventSink = null
                }
            }
        )
    }

    private fun registerNetworkCallback() {
        connectivityMgr = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                sendEvent("connected")
            }
            override fun onLost(network: Network) {
                sendEvent("disconnected")
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            connectivityMgr?.registerNetworkCallback(request, networkCallback!!)
        } else {
            connectivityMgr?.requestNetwork(request, networkCallback!!)
        }
    }

    private fun unregisterNetworkCallback() {
        connectivityMgr?.let { it.unregisterNetworkCallback(networkCallback!!) }
        networkCallback = null
    }

    private fun sendEvent(state: String) {
        eventSink?.success(state)   // "connected" | "disconnected"
    }

    override fun onDestroy() {
        unregisterNetworkCallback()
        super.onDestroy()
    }
}