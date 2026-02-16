import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('AndroidPrinter')
external AndroidPrinterInterface? androidPrinter;

@JSExport()
@staticInterop
class AndroidPrinterInterface {}

extension AndroidPrinterInterfaceExt on AndroidPrinterInterface {
  external void connect(JSString macAddress);
  external void print(JSString data);
  external void printBase64(JSString dataB64);
  external JSString? getPrinterMac();
  external bool setPrinterMac(JSString mac);
  external JSString listPaired();
  external bool checkConnection();
  external void diagnosticTest();
}

void connectToAndroidPrinter(String macAddress) {
  androidPrinter?.connect(macAddress.toJS);
}

void printToAndroidPrinter(String data) {
  androidPrinter?.print(data.toJS);
}

void printToAndroidPrinterBase64(String dataB64) {
  if (kDebugMode) {
    debugPrint('web_bridge: printToAndroidPrinterBase64 called');
    debugPrint('web_bridge: data length=${dataB64.length}');
    debugPrint('web_bridge: androidPrinter is null? ${androidPrinter == null}');
  }
  if (androidPrinter == null) {
    if (kDebugMode) {
      debugPrint('web_bridge: AndroidPrinter NULL - bridge not connected');
    }
    return;
  }
  if (kDebugMode) {
    debugPrint('web_bridge: calling AndroidPrinter.printBase64');
  }
  androidPrinter!.printBase64(dataB64.toJS);
  if (kDebugMode) {
    debugPrint('web_bridge: bridge call sent');
  }
}

String? getAndroidPrinterMac() {
  return androidPrinter?.getPrinterMac()?.toDart;
}

bool setAndroidPrinterMac(String mac) {
  return androidPrinter?.setPrinterMac(mac.toJS) ?? false;
}

bool checkAndroidPrinterConnection() {
  return androidPrinter?.checkConnection() ?? false;
}

void runAndroidPrinterDiagnostic() {
  androidPrinter?.diagnosticTest();
}

List<Map<String, String>> getAndroidPairedPrinters() {
  try {
    final json = androidPrinter?.listPaired().toDart ?? '[]';
    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => {
      'name': e['name'].toString(),
      'address': e['address'].toString(),
    }).toList();
  } catch (_) {
    return [];
  }
}

bool isAndroidPrinterAvailable() {
  return androidPrinter != null;
}
