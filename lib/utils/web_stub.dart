import 'dart:async';

class Window {
  final location = Location();
  final history = History();
  final navigator = Navigator();
  
  Stream get onPopState => const Stream.empty();

  void addEventListener(String type, Function listener) {}
  
  void open(String url, String target) {}
}

class Location {
  String get origin => '';
  String get hash => '';
}

class History {
  void pushState(dynamic data, String title, String? url) {}
}

class Navigator {
  bool get onLine => true;
}

final window = Window();
