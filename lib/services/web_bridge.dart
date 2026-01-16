import 'dart:js_interop';

@JS('AndroidPrinter')
external AndroidPrinterInterface? get androidPrinter;

@JS()
extension type AndroidPrinterInterface._(JSObject _) implements JSObject {
  external void connect(JSString macAddress);
  external void print(JSString data);
}

void connectToAndroidPrinter(String macAddress) {
  androidPrinter?.connect(macAddress.toJS);
}

void printToAndroidPrinter(String data) {
  androidPrinter?.print(data.toJS);
}
