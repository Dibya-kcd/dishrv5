import 'dart:convert';
import 'dart:js_interop';

@JS('AndroidPrinter')
external AndroidPrinterInterface? get androidPrinter;

@JS()
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
  androidPrinter?.printBase64(dataB64.toJS);
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
