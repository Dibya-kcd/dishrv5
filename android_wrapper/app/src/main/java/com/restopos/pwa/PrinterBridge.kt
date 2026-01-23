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
        val chunkSize = 512
        var offset = 0
        while (offset < bytes.size) {
            val length = min(chunkSize, bytes.size - offset)
            out.write(bytes, offset, length)
            out.flush()
            offset += length
            Thread.sleep(20) // Small delay between chunks
        }
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
                
                // Test print on connect
                val out = socket.outputStream
                Thread.sleep(100)
                
                out.write(byteArrayOf(0x1B, 0x40)) // ESC @ (Init)
                Thread.sleep(50)
                out.write("Printer Connected!\n".toByteArray(Charsets.UTF_8))
                out.write("Ready to print.\n\n\n\n".toByteArray(Charsets.UTF_8))
                out.flush()
                
                Thread.sleep(200)
                showToast("Printer connected successfully")
                
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
        var socket: BluetoothSocket? = null
        return try {
            val device = adapter.getRemoteDevice(mac)
            if (device.bondState != BluetoothDevice.BOND_BONDED) return false
            socket = connectSocket(device)
            socket != null
        } catch (_: Exception) {
            false
        } finally {
            try { socket?.close() } catch (_: IOException) {}
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
                
                Log.d(TAG, "Print: Data length = ${data.length}")
                
                val bytes = data.toByteArray(Charsets.UTF_8)
                out.write(bytes)
                out.flush()
                Thread.sleep(100)
                
                repeat(6) {
                    out.write(0x0A)
                }
                out.flush()
                
                Thread.sleep(200)
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
                
                val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                Log.d(TAG, "PrintBase64: Decoded ${bytes.size} bytes")
                
                // Log first 30 bytes for debugging
                if (bytes.size >= 30) {
                    Log.d(TAG, "First 30 bytes: ${bytes.take(30).joinToString(", ") { it.toString() }}")
                }
                
                // Check if data starts with ESC @ (init)
                if (bytes.size >= 2 && bytes[0] == 0x1B.toByte() && bytes[1] == 0x40.toByte()) {
                    Log.d(TAG, "Data starts with ESC @ - Good!")
                } else {
                    Log.w(TAG, "Data does NOT start with ESC @")
                }
                
                // Flutter's esc_pos_utils already includes ALL commands
                // Just send the bytes as-is
                writeChunks(out, bytes)
                
                Thread.sleep(300)
                showToast("Print sent")
                
            } catch (e: Exception) {
                Log.e(TAG, "PrintBase64 failed", e)
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