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
                val out = socket!!.outputStream
                Thread.sleep(150)
                val init = byteArrayOf(0x1B, 0x40)
                val std = byteArrayOf(0x1B, 0x53) // Standard mode
                val cancelReverse = byteArrayOf(0x1D, 0x42, 0x00) // Cancel white/black reverse
                val alignLeft = byteArrayOf(0x1B, 0x61, 0x00) // Align left
                val lineDefault = byteArrayOf(0x1B, 0x32) // Default line spacing
                val cp = byteArrayOf(0x1D, 0x74, 0x00) // Code page 0 (PC437)
                out.write(init)
                Thread.sleep(50)
                out.write(std)
                out.write(cancelReverse)
                out.write(alignLeft)
                out.write(lineDefault)
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
                val out = socket!!.outputStream
                Thread.sleep(150)
                val init = byteArrayOf(0x1B, 0x40)
                val std = byteArrayOf(0x1B, 0x53) // Standard mode
                val cancelReverse = byteArrayOf(0x1D, 0x42, 0x00) // Cancel white/black reverse
                val alignLeft = byteArrayOf(0x1B, 0x61, 0x00) // Align left
                val lineDefault = byteArrayOf(0x1B, 0x32) // Default line spacing
                val cp = byteArrayOf(0x1D, 0x74, 0x00) // Code page 0 (PC437)
                out.write(init)
                Thread.sleep(50)
                out.write(std)
                out.write(cancelReverse)
                out.write(alignLeft)
                out.write(lineDefault)
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

        Thread {
            var socket: BluetoothSocket? = null
            try {
                val device = adapter?.getRemoteDevice(mac)
                if (device == null) {
                    showToast("Device not found")
                    return@Thread
                }
                
                // Log connection attempt
                Log.i(TAG, "Diagnostic: Connecting to $mac")
                
                socket = try {
                    createSocket(device).also { it.connect() }
                } catch (e: Exception) {
                    Log.w(TAG, "Diagnostic: Secure connection failed, trying insecure", e)
                    createInsecureSocket(device).also { it.connect() }
                }

                val out = socket!!.outputStream
                
                // Test 1: Initialization
                Log.i(TAG, "Diagnostic: Sending ESC @ (Init)")
                out.write(byteArrayOf(0x1B, 0x40))
                // Force standard mode, cancel reverse, left align, default line spacing, code page 0
                out.write(byteArrayOf(0x1B, 0x53))
                out.write(byteArrayOf(0x1D, 0x42, 0x00))
                out.write(byteArrayOf(0x1B, 0x61, 0x00))
                out.write(byteArrayOf(0x1B, 0x32))
                out.write(byteArrayOf(0x1D, 0x74, 0x00))
                out.flush()
                Thread.sleep(500)

                // Test 2: Raw Text
                Log.i(TAG, "Diagnostic: Sending Raw Text 'TEST START'")
                out.write("TEST START\n".toByteArray())
                out.flush()
                Thread.sleep(200)

                // Test 3: Line Feeds
                Log.i(TAG, "Diagnostic: Sending Line Feeds")
                out.write("\n\n\n".toByteArray())
                out.flush()
                Thread.sleep(200)

                // Test 4: Multiple Characters
                Log.i(TAG, "Diagnostic: Sending Character Set")
                out.write("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\n".toByteArray())
                out.flush()
                Thread.sleep(200)

                // Test 5: Paper Cut
                Log.i(TAG, "Diagnostic: Sending Cut")
                out.write(byteArrayOf(0x1D, 0x56, 0x01))
                out.flush()
                
                Log.i(TAG, "Diagnostic: Completed successfully")
                showToast("Diagnostic Test Sent")

            } catch (e: Exception) {
                Log.e(TAG, "Diagnostic failed", e)
                showToast("Diagnostic Error: ${e.message}")
            } finally {
                try { socket?.close() } catch (e: Exception) {}
            }
        }.start()
    }

    @JavascriptInterface
    fun printAlternative(b64: String) {
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
                val device = adapter!!.getRemoteDevice(mac)
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    showToast("Pair printer in system settings")
                    return@Thread
                }
                
                socket = try {
                    createSocket(device).also { it.connect() }
                } catch (e: Exception) {
                    Log.w(TAG, "Secure connect failed, trying insecure", e)
                    createInsecureSocket(device).also { it.connect() }
                }

                val out = socket!!.outputStream
                
                // Alternative Init Sequence
                // Wake up (Null bytes)
                out.write(byteArrayOf(0x00, 0x00))
                Thread.sleep(50)
                
                // Init (ESC @)
                out.write(byteArrayOf(0x1B, 0x40))
                Thread.sleep(200)
                
                // Force standard mode, cancel reverse, left align, default line spacing
                out.write(byteArrayOf(0x1B, 0x53))
                out.write(byteArrayOf(0x1D, 0x42, 0x00))
                out.write(byteArrayOf(0x1B, 0x61, 0x00))
                out.write(byteArrayOf(0x1B, 0x32))
                // Code Page 437 (Standard) - GS t 0
                out.write(byteArrayOf(0x1D, 0x74, 0x00)) 
                Thread.sleep(50)

                val bytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                writeChunks(out, bytes)
                writeFinalization(out)
                
                showToast("Alt Print sent")
            } catch (e: Exception) {
                Log.e(TAG, "Alt Print failed", e)
                showToast("Alt Print failed: ${e.message}")
            } finally {
                try { socket?.close() } catch (_: IOException) {}
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
