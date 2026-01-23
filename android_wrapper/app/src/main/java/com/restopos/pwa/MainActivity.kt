package com.restopos.pwa

import android.Manifest
import android.os.Build
import android.os.Bundle
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private val requestPerms = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { permissions ->
        val allGranted = permissions.entries.all { it.value }
        if (!allGranted) {
            Toast.makeText(this, "Bluetooth permissions required for printer functionality", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        ensureBtPermissions()
        WebView.setWebContentsDebuggingEnabled(true)
        webView = findViewById(R.id.webview)
        val s: WebSettings = webView.settings
        s.javaScriptEnabled = true
        s.domStorageEnabled = true
        s.allowFileAccess = true
        s.loadsImagesAutomatically = true
        s.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        webView.webChromeClient = WebChromeClient()
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                injectBridgeShim()
            }
        }
        webView.addJavascriptInterface(PrinterBridge(this, webView), "AndroidPrinter")
        val url = "https://dibya-kcd.github.io/dishrv5/"
        webView.loadUrl(url)
    }

    private fun injectBridgeShim() {
        val js = """
            (function(){
              if (window.__androidPrinterShimInstalled) return;
              window.__androidPrinterShimInstalled = true;
              const origFetch = window.fetch;
              async function readBody(init) {
                try {
                  if (!init || !init.body) return '';
                  return await (new Response(init.body)).text();
                } catch (e) { 
                  try { 
                    if (typeof init.body === 'string') return init.body; 
                  } catch (_) {}
                  return '';
                }
              }
              async function bridgeFetch(input, init) {
                try {
                  const u = (typeof input === 'string') ? input : input.url;
                  if (u && u.indexOf('localhost:3001') !== -1) {
                    const urlObj = new URL(u);
                    const path = urlObj.pathname;
                    if (path === '/paired') {
                      const json = AndroidPrinter.listPaired();
                      return new Response(json, {status:200, headers:{'Content-Type':'application/json'}});
                    } else if (path === '/mac') {
                      const method = (init && init.method) ? String(init.method).toUpperCase() : 'GET';
                      if (method === 'POST') {
                        const body = await readBody(init);
                        AndroidPrinter.setPrinterMac(body || '');
                        return new Response(JSON.stringify({ok:true}), {status:200, headers:{'Content-Type':'application/json'}});
                      } else {
                        const mac = AndroidPrinter.getPrinterMac();
                        return new Response(JSON.stringify({mac: mac}), {status:200, headers:{'Content-Type':'application/json'}});
                      }
                    } else if (path === '/check') {
                      const ok = AndroidPrinter.checkConnection();
                      return new Response(JSON.stringify({ok: !!ok}), {status:200, headers:{'Content-Type':'application/json'}});
                    } else if (path === '/connect') {
                      const body = await readBody(init);
                      if (body) AndroidPrinter.setPrinterMac(body);
                      AndroidPrinter.connect(body || AndroidPrinter.getPrinterMac());
                      return new Response(JSON.stringify({ok:true}), {status:200, headers:{'Content-Type':'application/json'}});
                    } else if (path === '/print') {
                      const data = await readBody(init);
                      if (/^[A-Za-z0-9+/=]+$/.test(data || '')) {
                        AndroidPrinter.printBase64(data);
                      } else {
                        AndroidPrinter.print(data);
                      }
                      return new Response(JSON.stringify({ok:true}), {status:200, headers:{'Content-Type':'application/json'}});
                    } else {
                      return new Response(JSON.stringify({ok:true, shim:true}), {status:200, headers:{'Content-Type':'application/json'}});
                    }
                  }
                } catch (e) {
                  // fall through to network
                }
                return origFetch(input, init);
              }
              try { window.fetch = bridgeFetch; } catch (_) {}
            })();
        """.trimIndent()
        webView.evaluateJavascript(js, null)
    }
    private fun ensureBtPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            requestPerms.launch(arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN))
        }
    }

    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
}
