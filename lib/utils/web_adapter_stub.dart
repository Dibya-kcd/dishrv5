import 'dart:async';

void openNewTab(String url, {String? features}) {}

Future<void> openHtmlDocument(String htmlDoc) async {}

String locationOrigin() => '';

String locationHash() => '';

void historyPush(String url) {}

bool isOnline() => true;

bool androidBridgeAvailable() => false;

Future<List<Map<String, String>>> androidListPairedDevices() async => [];

Future<bool> androidPrintBytes(String mac, List<int> bytes) async => false;

Future<bool> androidPrintText(String mac, String text) async => false;
