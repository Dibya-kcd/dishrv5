package com.restopos.pwa

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.widget.Toast
import java.io.IOException
import java.io.OutputStream
import java.util.UUID
import kotlin.math.min

class PrinterBridge(private val context: Context, private val webView: WebView) {

    private val adapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val prefs = context.getSharedPreferences("printer_prefs", Context.MODE_PRIVATE)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastMac: String? = null

    @JavascriptInterface
    fun print(data: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                showToast("Bluetooth permission not granted")
                return
            }
        }
        val mac = prefs.getString(PREF_PRINTER_MAC, null)
        if (mac.isNullOrEmpty()) {
            showToast("No printer configured")
            return
        }
        if (!isValidMac(mac)) {
            showToast("Invalid MAC address")
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
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    showToast("Pair printer in system settings")
                    return@Thread
                }
                socket = createSocket(device)
                adapter.cancelDiscovery()
                socket.connect()
                val out = socket.outputStream
                Thread.sleep(150)
                val init = byteArrayOf(0x1B, 0x40)
                val cp = byteArrayOf(0x1D, 0x74, 0x00)
                out.write(init)
                Thread.sleep(50)
                out.write(cp)
                val bytes = data.toByteArray(Charsets.UTF_8)
                writeChunks(out, bytes)
                writeFinalization(out)
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
    fun printBase64(b64: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                showToast("Bluetooth permission not granted")
                return
            }
        }
        val mac = prefs.getString(PREF_PRINTER_MAC, null)
        if (mac.isNullOrEmpty()) {
            showToast("No printer configured")
            return
        }
        if (!isValidMac(mac)) {
            showToast("Invalid MAC address")
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
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    showToast("Pair printer in system settings")
                    return@Thread
                }
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
                Thread.sleep(150)
                val init = byteArrayOf(0x1B, 0x40)
                val cp = byteArrayOf(0x1D, 0x74, 0x00)
                out.write(init)
                Thread.sleep(50)
                out.write(cp)
                val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                writeChunks(out, bytes)
                writeFinalization(out)
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                showToast("Bluetooth permission not granted")
                return
            }
        }
        if (!isValidMac(macAddress)) {
            showToast("Invalid MAC address")
            return
        }
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
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    showToast("Pair printer in system settings")
                    return@Thread
                }
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

    private fun writeChunks(out: OutputStream, bytes: ByteArray, chunkSize: Int = 256) {
        var i = 0
        while (i < bytes.size) {
            val end = min(i + chunkSize, bytes.size)
            out.write(bytes, i, end - i)
            out.flush()
            Thread.sleep(10)
            i = end
        }
    }

    private fun writeFinalization(out: OutputStream) {
        val lf = byteArrayOf(0x0A)
        repeat(6) { out.write(lf) }
        out.flush()
        val cut = byteArrayOf(0x1D, 0x56, 0x01)
        out.write(cut)
        out.flush()
        Thread.sleep(200)
    }

    private fun isValidMac(mac: String): Boolean {
        val regex = Regex("^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}\$")
        return regex.matches(mac)
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
