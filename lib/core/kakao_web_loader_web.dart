import "dart:async";
import "dart:html" as html;

bool _ready = false;
Future<bool>? _loading;

bool get isKakaoWebSdkReady => _ready;

Future<bool> ensureKakaoWebSdk(String javascriptKey) {
  if (_ready) return Future.value(true);
  if (javascriptKey.isEmpty) return Future.value(false);
  return _loading ??= _load(javascriptKey);
}

Future<bool> _load(String javascriptKey) async {
  final existing = html.document.querySelector(
    'script[data-ensom-kakao-maps="true"]',
  );
  if (existing != null) {
    _ready = existing.getAttribute("data-loaded") == "true";
    return _ready;
  }

  final completer = Completer<bool>();
  final script = html.ScriptElement()
    ..src =
        "https://dapi.kakao.com/v2/maps/sdk.js?appkey=${Uri.encodeQueryComponent(javascriptKey)}"
    ..async = true
    ..setAttribute("data-ensom-kakao-maps", "true");

  script.onLoad.first.then((_) {
    script.setAttribute("data-loaded", "true");
    _ready = true;
    if (!completer.isCompleted) completer.complete(true);
  });
  script.onError.first.then((_) {
    if (!completer.isCompleted) completer.complete(false);
  });
  html.document.head?.append(script);

  try {
    return await completer.future.timeout(const Duration(seconds: 15));
  } on TimeoutException {
    return false;
  }
}
