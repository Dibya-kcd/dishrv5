import 'package:web/web.dart' as web;
import 'dart:convert';
import 'dart:js_util' as js_util;

void openNewTab(String url, {String? features}) {
  web.window.open(url, '_blank', features ?? '');
}

Future<void> openHtmlDocument(String htmlDoc) async {
  final encoded = Uri.encodeComponent(htmlDoc);
  final url = 'data:text/html;charset=utf-8,$encoded';
  final a = web.HTMLAnchorElement();
  a.href = url;
  a.target = '_blank';
  a.rel = 'noopener';
  web.document.body?.append(a);
  a.click();
  a.remove();
}

String locationOrigin() {
  final loc = web.window.location;
  return loc.origin;
}

String locationHash() {
  final loc = web.window.location;
  return loc.hash;
}

void historyPush(String url) {
  web.window.history.pushState(null, '', url);
}

bool isOnline() {
  final nav = web.window.navigator;
  return nav.onLine;
}

bool androidBridgeAvailable() {
  final bridge = js_util.getProperty(web.window, 'AndroidPrinter');
  return bridge != null;
}

Future<List<Map<String, String>>> androidListPairedDevices() async {
  final bridge = js_util.getProperty(web.window, 'AndroidPrinter');
  if (bridge == null) return [];
  final jsonString = js_util.callMethod<String>(bridge, 'listPaired', const []);
  try {
    final decoded = json.decode(jsonString) as List<dynamic>;
    return decoded.map<Map<String, String>>((e) {
      final m = e as Map<String, dynamic>;
      return {
        'name': '${m['name'] ?? ''}',
        'mac': '${m['mac'] ?? ''}',
      };
    }).toList();
  } catch (_) {
    return [];
  }
}

Future<bool> androidPrintBytes(String mac, List<int> bytes) async {
  final bridge = js_util.getProperty(web.window, 'AndroidPrinter');
  if (bridge == null) return false;
  final b64 = base64Encode(bytes);
  final ok = js_util.callMethod<bool>(bridge, 'printBase64', [mac, b64]);
  return ok == true;
}

Future<bool> androidPrintText(String mac, String text) async {
  final bridge = js_util.getProperty(web.window, 'AndroidPrinter');
  if (bridge == null) return false;
  final ok = js_util.callMethod<bool>(bridge, 'printText', [mac, text]);
  return ok == true;
}
