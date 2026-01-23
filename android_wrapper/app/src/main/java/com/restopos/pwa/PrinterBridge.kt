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
            arr.append("{\"name\":\"").append(d.name ?: "").append("\",\"address\":\"").append(d.address).append("\"}")
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

    private fun connectSocket(device: BluetoothDevice): BluetoothSocket? {
        var socket: BluetoothSocket? = null
        try {
            adapter?.cancelDiscovery()
            // Secure socket is preferred, but insecure might be needed for some printers
            // Try secure first
            socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
        } catch (e: IOException) {
            Log.e(TAG, "Secure socket connect failed, trying insecure", e)
            try {
                try { socket?.close() } catch (_: IOException) {}
                adapter?.cancelDiscovery()
                socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
            } catch (e2: IOException) {
                Log.e(TAG, "Insecure socket connect also failed", e2)
                try { socket?.close() } catch (_: IOException) {}
                return null
            }
        }
        return socket
    }

    private fun writeChunks(out: OutputStream, bytes: ByteArray) {
        val chunkSize = 1024
        var offset = 0
        while (offset < bytes.size) {
            val length = min(chunkSize, bytes.size - offset)
            out.write(bytes, offset, length)
            out.flush()
            offset += length
            try {
                Thread.sleep(50) // Small delay between chunks to avoid buffer overflow
            } catch (e: InterruptedException) {
                e.printStackTrace()
            }
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
                
                // Simple approach for text data
                val bytes = data.toByteArray(Charsets.UTF_8)
                out.write(bytes)
                out.flush()
                Thread.sleep(100)
                
                // Add line feeds
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
                
                // CRITICAL: Flutter's esc_pos_utils already includes ALL ESC/POS commands 
                // including INIT, formatting, and CUT. We should NOT add anything extra. 
                // Just send the bytes as-is. 
                
                writeChunks(out, bytes)
                
                Thread.sleep(300) // Wait for printer to finish
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
                 if (device?.bondState != BluetoothDevice.BOND_BONDED) {
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
                 
                 val msg = "\n\nDiagnostic Test\nSuccessful!\n\n\n\n"
                 out.write(msg.toByteArray(Charsets.UTF_8))
                 out.flush()
                 
                 showToast("Diagnostic sent")
                 
             } catch (e: Exception) {
                 Log.e(TAG, "Diagnostic failed", e)
                 showToast("Diagnostic failed: ${e.message}")
             } finally {
                 try {
                     socket?.close()
                 } catch (_: IOException) {}
             }
        }.start()
    }
}
