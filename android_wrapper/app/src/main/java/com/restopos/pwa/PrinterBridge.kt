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

    companion object {
        private const val TAG = "PrinterBridge"
        private const val PREF_PRINTER_MAC = "pref_printer_mac"
        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private fun showToast(msg: String) {
        mainHandler.post {
            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
        }
    }

    private fun isValidMac(mac: String): Boolean {
        return BluetoothAdapter.checkBluetoothAddress(mac)
    }

    private fun connectSocket(device: BluetoothDevice): BluetoothSocket? {
        adapter?.cancelDiscovery() // CRITICAL: Cancel discovery first
        
        var socket: BluetoothSocket? = null
        try {
            socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
            Log.d(TAG, "Secure connection successful")
        } catch (e: IOException) {
            Log.w(TAG, "Secure connect failed, trying insecure", e)
            try {
                socket?.close()
            } catch (_: IOException) {}
            
            try {
                socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                Log.d(TAG, "Insecure connection successful")
            } catch (e2: IOException) {
                Log.e(TAG, "Both connection methods failed", e2)
                try {
                    socket?.close()
                } catch (_: IOException) {}
                return null
            }
        }
        return socket
    }

    private fun writeChunks(out: OutputStream, bytes: ByteArray) {
        val chunkSize = 128
        var offset = 0
        while (offset < bytes.size) {
            val length = min(chunkSize, bytes.size - offset)
            try {
                out.write(bytes, offset, length)
                out.flush()
                offset += length
                Thread.sleep(15)
            } catch (e: IOException) {
                Log.e(TAG, "Write failed at offset $offset/${bytes.size}: ${e.message}")
                throw e
            }
        }
    }

    private fun writeFinalization(out: OutputStream) {
        val lf = 0x0A
        repeat(6) { out.write(lf) }
        out.flush()
        val cut = byteArrayOf(0x1D, 0x56, 0x01)
        out.write(cut)
        out.flush()
        Thread.sleep(200)
    }

    private fun hexPreview(bytes: ByteArray, count: Int): String {
        val n = kotlin.math.min(count, bytes.size)
        val sb = StringBuilder()
        for (i in 0 until n) {
            val b = bytes[i].toInt() and 0xFF
            if (i > 0) sb.append(" ")
            sb.append(String.format("%02X", b))
        }
        return sb.toString()
    }

    private fun containsSeq(bytes: ByteArray, seq: ByteArray): Boolean {
        if (seq.isEmpty() || bytes.size < seq.size) return false
        var i = 0
        while (i <= bytes.size - seq.size) {
            var match = true
            var j = 0
            while (j < seq.size) {
                if (bytes[i + j] != seq[j]) {
                    match = false
                    break
                }
                j++
            }
            if (match) return true
            i++
        }
        return false
    }

    // JavaScript Interface Methods

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
        
        // Save the MAC address
        prefs.edit().putString(PREF_PRINTER_MAC, macAddress).apply()
        
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter.getRemoteDevice(macAddress)
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    showToast("Pair printer in Bluetooth settings first")
                    return@Thread
                }
                
                socket = connectSocket(device)
                if (socket == null) {
                    showToast("Connection failed")
                    return@Thread
                }
                // Only check connectivity; do not print anything here
                Thread.sleep(150)
                showToast("Printer connection OK")
                
            } catch (e: Exception) {
                Log.e(TAG, "Connection failed", e)
                showToast("Connection failed: ${e.message}")
            } finally {
                try {
                    Thread.sleep(100)
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }.start()
    }

    @JavascriptInterface
    fun setPrinterMac(mac: String): Boolean {
        if (!isValidMac(mac)) return false
        prefs.edit().putString(PREF_PRINTER_MAC, mac).apply()
        return true
    }

    @JavascriptInterface
    fun getPrinterMac(): String? {
        return prefs.getString(PREF_PRINTER_MAC, null)
    }

    @JavascriptInterface
    fun clearPrinterMac() {
        prefs.edit().remove(PREF_PRINTER_MAC).apply()
    }

    @JavascriptInterface
    fun listPaired(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                return "[]"
            }
        }
        val set = adapter?.bondedDevices ?: emptySet()
        val arr = StringBuilder("[")
        var first = true
        for (d in set) {
            if (!first) arr.append(",")
            arr.append("{\"name\":\"").append(d.name ?: "Unknown").append("\",\"address\":\"").append(d.address).append("\"}")
            first = false
        }
        arr.append("]")
        return arr.toString()
    }

    @JavascriptInterface
    fun checkConnection(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        val mac = prefs.getString(PREF_PRINTER_MAC, null) ?: return false
        if (!isValidMac(mac)) return false
        if (adapter == null || !adapter.isEnabled) return false
        // Lightweight check: ensure device exists and is bonded; do not open a socket
        return try {
            val device = adapter.getRemoteDevice(mac)
            device.bondState == BluetoothDevice.BOND_BONDED
        } catch (_: Exception) {
            false
        }
    }

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
                
                socket = connectSocket(device)
                if (socket == null) {
                    showToast("Connection failed")
                    return@Thread
                }
                
                val out = socket.outputStream
                Thread.sleep(100)
                
                val wake = byteArrayOf(0x00, 0x00)
                val init = byteArrayOf(0x1B, 0x40)
                val std = byteArrayOf(0x1B, 0x53)
                val cancelReverse = byteArrayOf(0x1D, 0x42, 0x00)
                val alignLeft = byteArrayOf(0x1B, 0x61, 0x00)
                val lineDefault = byteArrayOf(0x1B, 0x32)
                val resetMode = byteArrayOf(0x1B, 0x21, 0x00)
                val escT0 = byteArrayOf(0x1B, 0x74, 0x00) // ESC t 0 (codepage 0 / CP437)
                out.write(wake)
                Thread.sleep(50)
                out.write(init)
                Thread.sleep(200)
                out.write(std)
                out.write(cancelReverse)
                out.write(alignLeft)
                out.write(lineDefault)
                out.write(resetMode)
                out.write(escT0)
                Thread.sleep(50)
                val bytes = data.toByteArray(Charsets.UTF_8)
                Log.i(TAG, "Hex preview: ${hexPreview(bytes, 64)}")
                Log.i(TAG, "Has ESC @: ${containsSeq(bytes, byteArrayOf(0x1B, 0x40))} • Has GS V: ${containsSeq(bytes, byteArrayOf(0x1D, 0x56))}")
                writeChunks(out, bytes)
                writeFinalization(out)
                showToast("Print sent")
                
            } catch (e: Exception) {
                Log.e(TAG, "Print failed", e)
                showToast("Print failed: ${e.message}")
            } finally {
                try {
                    Thread.sleep(100)
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }.start()
    }

    @JavascriptInterface
    fun printBase64(b64: String) {
        Log.i(TAG, "printBase64 invoked")
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
            var attempt = 0
            val maxRetries = 2
            var success = false
            
            while (!success && attempt < maxRetries) {
                attempt++
                Log.i(TAG, "Print attempt $attempt of $maxRetries")
                var socket: BluetoothSocket? = null
                
                try {
                    val device = adapter.getRemoteDevice(mac)
                    if (device.bondState != BluetoothDevice.BOND_BONDED) {
                        showToast("Pair printer in system settings")
                        return@Thread
                    }
                    
                    socket = connectSocket(device)
                    if (socket == null) {
                        Log.w(TAG, "Connection failed on attempt $attempt")
                        if (attempt == maxRetries) showToast("Connection failed")
                        continue
                    }
                    
                    val out = socket.outputStream
                    Thread.sleep(100)
                    
                    val wake = byteArrayOf(0x00, 0x00)
                    val init = byteArrayOf(0x1B, 0x40)
                    val std = byteArrayOf(0x1B, 0x53)
                    val cancelReverse = byteArrayOf(0x1D, 0x42, 0x00)
                    val alignLeft = byteArrayOf(0x1B, 0x61, 0x00)
                    val lineDefault = byteArrayOf(0x1B, 0x32)
                    val resetMode = byteArrayOf(0x1B, 0x21, 0x00)
                    val escT0 = byteArrayOf(0x1B, 0x74, 0x00) // ESC t 0 (codepage 0 / CP437)
                    out.write(wake)
                    Thread.sleep(50)
                    out.write(init)
                    Thread.sleep(200)
                    out.write(std)
                    out.write(cancelReverse)
                    out.write(alignLeft)
                    out.write(lineDefault)
                    out.write(resetMode)
                    out.write(escT0)
                    Thread.sleep(50)
                    val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                    Log.i(TAG, "Decoded base64 length: ${bytes.size}")
                    Log.i(TAG, "Hex preview: ${hexPreview(bytes, 64)}")
                    Log.i(TAG, "Has ESC @: ${containsSeq(bytes, byteArrayOf(0x1B, 0x40))} • Has GS V: ${containsSeq(bytes, byteArrayOf(0x1D, 0x56))}")
                    writeChunks(out, bytes)
                    writeFinalization(out)
                    
                    success = true
                    showToast("Print sent")
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Print attempt $attempt failed: ${e.message}", e)
                    try { socket?.close() } catch (_: IOException) {}
                    if (attempt < maxRetries) {
                        Thread.sleep(1000)
                    } else {
                        showToast("Print failed: ${e.message}")
                    }
                } finally {
                    try {
                        Thread.sleep(100)
                        socket?.close()
                    } catch (_: IOException) {}
                }
            }
        }.start()
    }

    @JavascriptInterface
    fun diagnosticTest() {
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
        
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter?.getRemoteDevice(mac)
                if (device == null) {
                    showToast("Device not found")
                    return@Thread
                }
                
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    showToast("Pair printer in system settings")
                    return@Thread
                }
                
                Log.i(TAG, "Diagnostic: Connecting to $mac")
                
                socket = connectSocket(device)
                if (socket == null) {
                    showToast("Connection failed")
                    return@Thread
                }

                val out = socket.outputStream
                Thread.sleep(100)
                
                // Test 1: Init
                Log.i(TAG, "Test 1: ESC @ (Init)")
                out.write(byteArrayOf(0x1B, 0x40))
                out.flush()
                Thread.sleep(100)
                
                // Test 2: Simple text
                Log.i(TAG, "Test 2: Raw text")
                out.write("DIAGNOSTIC TEST\n".toByteArray(Charsets.UTF_8))
                out.flush()
                Thread.sleep(200)
                
                // Test 3: Bold
                Log.i(TAG, "Test 3: Bold text")
                out.write(byteArrayOf(0x1B, 0x45, 0x01))
                out.write("BOLD TEXT\n".toByteArray(Charsets.UTF_8))
                out.write(byteArrayOf(0x1B, 0x45, 0x00))
                out.flush()
                Thread.sleep(200)
                
                // Test 4: Line feeds
                Log.i(TAG, "Test 4: Line feeds")
                repeat(8) {
                    out.write(0x0A)
                }
                out.flush()
                
                Thread.sleep(300)
                Log.i(TAG, "Diagnostic completed")
                showToast("Diagnostic test sent - check printer")

            } catch (e: Exception) {
                Log.e(TAG, "Diagnostic failed: ${e.message}", e)
                showToast("Diagnostic failed: ${e.message}")
            } finally {
                try {
                    Thread.sleep(100)
                    socket?.close()
                } catch (e: Exception) {}
            }
        }.start()
    }
}
