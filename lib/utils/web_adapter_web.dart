import 'package:web/web.dart' as web;

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
