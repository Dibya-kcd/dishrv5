import 'dart:js_interop';

@JS('AndroidPrinter')
external AndroidPrinterInterface? get androidPrinter;

@JS()
extension type AndroidPrinterInterface._(JSObject _) implements JSObject {
  external void connect(JSString macAddress);
  external void print(JSString data);
  external void printBase64(JSString dataB64);
  external void diagnosticTest();
  external void printAlternative(JSString dataB64);
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

void runAndroidDiagnostic() {
  androidPrinter?.diagnosticTest();
}

void printToAndroidPrinterAlternativeBase64(String dataB64) {
  androidPrinter?.printAlternative(dataB64.toJS);
}
