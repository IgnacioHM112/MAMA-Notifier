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
import android.util.Log

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mama_notifier/wifi_events"
    private val TAG = "MamaNotifierMain"
    private var connectivityMgr: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isListening = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        try {
                            eventSink = events
                            registerNetworkCallback()
                            isListening = true
                            Log.d(TAG, "EventChannel onListen - registered NetworkCallback")
                        } catch (e: Exception) {
                            Log.e(TAG, "onListen ERROR", e)
                            events?.error("ERROR", "onListen failed", e.message)
                        }
                    }
                    override fun onCancel(arguments: Any?) {
                        try {
                            unregisterNetworkCallback()
                            eventSink = null
                            isListening = false
                            Log.d(TAG, "EventChannel onCancel - unregistered NetworkCallback")
                        } catch (e: Exception) {
                            Log.e(TAG, "onCancel ERROR", e)
                        }
                    }
                }
            )
            Log.d(TAG, "EventChannel configured successfully")
        } catch (e: Exception) {
            Log.e(TAG, "configureFlutterEngine ERROR", e)
        }
    }

    private fun registerNetworkCallback() {
        try {
            connectivityMgr = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    try {
                        sendEvent("connected")
                        Log.d(TAG, "NetworkCallback onAvailable - connected")
                    } catch (e: Exception) {
                        Log.e(TAG, "onAvailable ERROR", e)
                    }
                }
                override fun onLost(network: Network) {
                    try {
                        sendEvent("disconnected")
                        Log.d(TAG, "NetworkCallback onLost - disconnected")
                    } catch (e: Exception) {
                        Log.e(TAG, "onLost ERROR", e)
                    }
                }
                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    try {
                        val hasWifi = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                        sendEvent(if (hasWifi) "connected" else "disconnected")
                        Log.d(TAG, "NetworkCallback onCapabilitiesChanged - hasWifi=$hasWifi")
                    } catch (e: Exception) {
                        Log.e(TAG, "onCapabilitiesChanged ERROR", e)
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                connectivityMgr?.registerNetworkCallback(request, networkCallback!!)
            } else {
                connectivityMgr?.requestNetwork(request, networkCallback!!)
            }
            Log.d(TAG, "NetworkCallback registered")
        } catch (e: Exception) {
            Log.e(TAG, "registerNetworkCallback ERROR", e)
        }
    }

    private fun unregisterNetworkCallback() {
        try {
            connectivityMgr?.let { it.unregisterNetworkCallback(networkCallback!!) }
            networkCallback = null
            Log.d(TAG, "NetworkCallback unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "unregisterNetworkCallback ERROR", e)
        }
    }

    private fun sendEvent(state: String) {
        try {
            eventSink?.success(state)
            Log.d(TAG, "Event sent: $state")
        } catch (e: Exception) {
            Log.e(TAG, "sendEvent ERROR", e)
        }
    }

    override fun onDestroy() {
        try {
            unregisterNetworkCallback()
        } catch (e: Exception) {
            Log.e(TAG, "onDestroy ERROR", e)
        }
        super.onDestroy()
    }
}