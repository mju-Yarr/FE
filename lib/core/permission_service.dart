import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:permission_handler/permission_handler.dart";

/// 권한 요청 중앙 서비스.
///
/// 온보딩 프라이밍 및 기능 진입점에서 OS 권한을 요청하고,
/// 상태에 따라 적절한 안내를 보여준다.
///
/// 위치 권한은 플랫폼별로 경로가 다르다:
/// - 모바일(iOS/Android): permission_handler의 Permission.location
/// - 웹: permission_handler는 브라우저 위치 프롬프트를 띄우지 못한다.
///   geolocator(geolocator_web)의 requestPermission()이 브라우저 Geolocation
///   권한 프롬프트를 실제로 띄우므로 웹에서는 이 경로를 쓴다. 반환값은
///   호출부 호환을 위해 PermissionStatus로 매핑한다.
class PermissionService {
  PermissionService._();
  static final instance = PermissionService._();

  /// geolocator의 LocationPermission을 permission_handler의 PermissionStatus로
  /// 매핑한다(웹 경로). 호출부가 status.isGranted만 보므로 granted 여부가 핵심.
  static PermissionStatus _mapGeolocatorPermission(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return PermissionStatus.granted;
      case LocationPermission.deniedForever:
        return PermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return PermissionStatus.denied;
    }
  }

  /// 알림 권한 요청.
  Future<PermissionStatus> requestNotification() async {
    final status = await Permission.notification.request();
    return status;
  }

  Future<PermissionStatus> notificationStatus() =>
      Permission.notification.status;

  Future<PermissionStatus> locationStatus() async {
    if (kIsWeb) {
      return _mapGeolocatorPermission(await Geolocator.checkPermission());
    }
    return Permission.location.status;
  }

  Future<PermissionStatus> locationAlwaysStatus() async {
    if (kIsWeb) return locationStatus();
    return Permission.locationAlways.status;
  }

  /// 위치 권한 요청 (whenInUse만).
  /// 온보딩·프라이밍에서 사용한다. always는 별도로 요청한다.
  Future<PermissionStatus> requestLocation() async {
    if (kIsWeb) {
      // 웹은 geolocator가 브라우저 위치 권한 프롬프트를 띄운다.
      // 이미 결정된 상태면 프롬프트 없이 현재 값을 돌려주므로, denied일 때만
      // requestPermission()으로 프롬프트를 유발한다.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _mapGeolocatorPermission(permission);
    }
    final status = await Permission.location.request();
    return status;
  }

  /// 항상 위치 권한 요청 (always).
  /// 명세대로 자동 출발·도착 확인 기능 활성화 시 별도 화면에서 요청.
  Future<PermissionStatus> requestLocationAlways() async {
    if (kIsWeb) {
      // 웹 브라우저에는 "항상 위치" 개념이 없다 — whenInUse와 동일하게 처리.
      return requestLocation();
    }
    final status = await Permission.locationAlways.request();
    return status;
  }

  /// 모든 필수 권한이 허용되었는지 확인.
  Future<bool> isAllGranted() async {
    final notification = await Permission.notification.isGranted;
    final location = kIsWeb
        ? _mapGeolocatorPermission(await Geolocator.checkPermission()).isGranted
        : await Permission.location.isGranted;
    return notification && location;
  }

  /// 권한이 거부되었을 때 사유 안내 다이얼로그를 표시한다.
  /// permanentlyDenied이면 시스템 설정으로 안내한다.
  Future<void> showRationale(
    BuildContext context,
    PermissionRationaleType type,
  ) async {
    final title = switch (type) {
      PermissionRationaleType.notification => "알림 권한이 필요해요",
      PermissionRationaleType.location => "위치 권한이 필요해요",
    };

    final description = switch (type) {
      PermissionRationaleType.notification =>
        "준비 시작과 출발 시각을 놓치지 않도록 알려드리기 위해 알림 권한이 필요해요. "
            "권한이 없어도 앱은 계속 사용할 수 있지만, 시간 알림을 받을 수 없어요.",
      PermissionRationaleType.location =>
        "출발·도착을 자동으로 감지해서 더 정확한 시간 계획을 세우기 위해 위치 권한이 필요해요. "
            "권한이 없어도 앱은 계속 사용할 수 있지만, 자동 감지 기능이 동작하지 않아요.",
    };

    final permission = switch (type) {
      PermissionRationaleType.notification => Permission.notification,
      PermissionRationaleType.location => Permission.location,
    };

    final status = await permission.status;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("괜찮아요"),
          ),
          if (status.isPermanentlyDenied)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAppSettings();
              },
              child: const Text("설정 열기"),
            ),
        ],
      ),
    );
  }
}

enum PermissionRationaleType { notification, location }
