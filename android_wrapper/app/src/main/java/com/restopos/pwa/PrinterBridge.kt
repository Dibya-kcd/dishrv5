package com.restopos.pwa

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.widget.Toast
import java.io.IOException
import java.util.UUID

class PrinterBridge(private val context: Context, private val webView: WebView) {

    private val adapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val prefs = context.getSharedPreferences("printer_prefs", Context.MODE_PRIVATE)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastMac: String? = null

    @JavascriptInterface
    fun print(data: String) {
        val mac = prefs.getString(PREF_PRINTER_MAC, null)
        if (mac.isNullOrEmpty()) {
            showToast("No printer configured")
            return
        }
        if (adapter == null || !adapter.isEnabled) {
            showToast("Bluetooth not available")
            return
        }
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter.getRemoteDevice(mac)
                socket = createSocket(device)
                adapter.cancelDiscovery()
                socket.connect()
                val out = socket.outputStream
                val bytes = data.toByteArray(Charsets.UTF_8)
                out.write(bytes)
                out.flush()
                showToast("Print sent")
            } catch (e: Exception) {
                Log.e(TAG, "Print failed", e)
                showToast("Print failed")
            } finally {
                try {
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }.start()
    }

    // Accept Base64-encoded bytes from Flutter Web and send raw ESC/POS bytes
    @JavascriptInterface
    fun printBase64(b64: String) {
        val mac = prefs.getString(PREF_PRINTER_MAC, null)
        if (mac.isNullOrEmpty()) {
            showToast("No printer configured")
            return
        }
        if (adapter == null || !adapter.isEnabled) {
            showToast("Bluetooth not available")
            return
        }
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter.getRemoteDevice(mac)
                socket = createSocket(device)
                adapter.cancelDiscovery()
                try {
                    socket.connect()
                } catch (e: Exception) {
                    Log.w(TAG, "Secure connect failed, trying insecure", e)
                    try { socket.close() } catch (_: IOException) {}
                    socket = createInsecureSocket(device)
                    socket.connect()
                }
                val out = socket.outputStream
                val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                out.write(bytes)
                out.flush()
                showToast("Print sent")
            } catch (e: Exception) {
                Log.e(TAG, "Print failed", e)
                showToast("Print failed")
            } finally {
                try {
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }.start()
    }

    @JavascriptInterface
    fun connect(macAddress: String) {
        if (adapter == null || !adapter.isEnabled) {
            showToast("Bluetooth not available")
            return
        }
        prefs.edit().putString(PREF_PRINTER_MAC, macAddress).apply()
        lastMac = macAddress
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter.getRemoteDevice(macAddress)
                socket = createSocket(device)
                adapter.cancelDiscovery()
                try {
                    socket.connect()
                } catch (e: Exception) {
                    Log.w(TAG, "Secure connect failed, trying insecure", e)
                    try { socket.close() } catch (_: IOException) {}
                    socket = createInsecureSocket(device)
                    socket.connect()
                }
                showToast("Printer connected")
            } catch (e: Exception) {
                Log.e(TAG, "Connection failed", e)
                showToast("Connection failed")
            } finally {
                try {
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }.start()
    }

    private fun createSocket(device: BluetoothDevice): BluetoothSocket {
        return device.createRfcommSocketToServiceRecord(SPP_UUID)
    }

    private fun createInsecureSocket(device: BluetoothDevice): BluetoothSocket {
        return try {
            device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
        } catch (e: Exception) {
            Log.w(TAG, "Insecure socket creation failed, falling back to secure", e)
            device.createRfcommSocketToServiceRecord(SPP_UUID)
        }
    }

    private fun showToast(message: String) {
        mainHandler.post {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        private const val TAG = "PrinterBridge"
        private const val PREF_PRINTER_MAC = "printer_mac"
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
