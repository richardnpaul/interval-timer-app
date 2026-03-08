import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// --- Background Service Wrapper ---

class BackgroundServiceWrapper {
  Stream<Map<String, dynamic>?> on(String method) =>
      FlutterBackgroundService().on(method);
  void invoke(String method, [Map<String, dynamic>? args]) =>
      FlutterBackgroundService().invoke(method, args);
}

final backgroundServiceWrapperProvider = Provider<BackgroundServiceWrapper>(
  (ref) => BackgroundServiceWrapper(),
);

// --- Permission Service ---

class PermissionService {
  Future<PermissionStatus> requestNotificationPermission() =>
      Permission.notification.request();
}

final permissionServiceProvider = Provider((ref) => PermissionService());

// --- Settings Service ---

class SettingsService {
  Future<bool> isWakelockEnabled() => WakelockPlus.enabled;
  Future<void> setWakelock(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();
}

final settingsServiceProvider = Provider((ref) => SettingsService());
