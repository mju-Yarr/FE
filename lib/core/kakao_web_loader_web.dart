import "dart:async";
import "dart:html" as html;
import "dart:js_interop";

@JS("kakao.maps.load")
external void _loadKakaoMaps(JSFunction callback);

@JS("kakao.maps.Map")
external JSFunction? get _kakaoMapConstructor;

bool _ready = false;
Future<bool>? _loading;

bool get isKakaoWebSdkReady => _ready;

Future<bool> ensureKakaoWebSdk(String javascriptKey) {
  if (_ready) return Future.value(true);
  if (javascriptKey.isEmpty) return Future.value(false);
  final inFlight = _loading;
  if (inFlight != null) return inFlight;

  final loading = _load(javascriptKey);
  _loading = loading;
  return loading.whenComplete(() {
    if (!_ready) _loading = null;
  });
}

Future<bool> _load(String javascriptKey) async {
  final existing = html.document.querySelector(
    'script[data-ensom-kakao-maps="true"]',
  );
  if (existing != null) {
    if (existing.getAttribute("data-ready") == "true") {
      _ready = true;
      return true;
    }
    existing.remove();
  }

  final completer = Completer<bool>();
  final script = html.ScriptElement()
    ..src =
        "https://dapi.kakao.com/v2/maps/sdk.js?appkey=${Uri.encodeQueryComponent(javascriptKey)}&autoload=false"
    ..async = true
    ..setAttribute("data-ensom-kakao-maps", "true");

  script.onLoad.first.then((_) {
    script.setAttribute("data-loaded", "true");
    try {
      _loadKakaoMaps(
        (() {
          final ready = _kakaoMapConstructor != null;
          _ready = ready;
          if (ready) script.setAttribute("data-ready", "true");
          if (!completer.isCompleted) completer.complete(ready);
        }).toJS,
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
  });
  script.onError.first.then((_) {
    if (!completer.isCompleted) completer.complete(false);
  });
  html.document.head?.append(script);

  try {
    final loaded = await completer.future.timeout(const Duration(seconds: 15));
    if (!loaded) script.remove();
    return loaded;
  } on TimeoutException {
    script.remove();
    return false;
  }
}
