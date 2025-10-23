import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SyncService {
  static const String _syncIdKey = 'sync_id';
  static const String _deviceIdKey = 'device_id';

  // Generate or get existing sync ID
  static Future<String> getSyncId() async {
    final prefs = await SharedPreferences.getInstance();
    String? syncId = prefs.getString(_syncIdKey);

    if (syncId == null) {
      syncId = const Uuid().v4();
      await prefs.setString(_syncIdKey, syncId);
    }

    return syncId;
  }

  // Set sync ID (for connecting to another device)
  static Future<void> setSyncId(String syncId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncIdKey, syncId);
  }

  // Get unique device identifier
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      if (kIsWeb) {
        // For web platform, just generate a UUID
        deviceId = const Uuid().v4();
      } else {
        // For mobile/desktop platforms
        try {
          final deviceInfo = DeviceInfoPlugin();
          final baseDeviceInfo = await deviceInfo.deviceInfo;

          // Get device-specific ID based on the platform
          if (baseDeviceInfo is AndroidDeviceInfo) {
            deviceId = baseDeviceInfo.id;
          } else if (baseDeviceInfo is IosDeviceInfo) {
            deviceId = baseDeviceInfo.identifierForVendor ?? const Uuid().v4();
          } else if (baseDeviceInfo is WindowsDeviceInfo) {
            deviceId = baseDeviceInfo.deviceId;
          } else if (baseDeviceInfo is MacOsDeviceInfo) {
            deviceId = baseDeviceInfo.systemGUID ?? const Uuid().v4();
          } else if (baseDeviceInfo is LinuxDeviceInfo) {
            deviceId = baseDeviceInfo.machineId ?? const Uuid().v4();
          } else {
            deviceId = const Uuid().v4();
          }
        } catch (e) {
          print('Error getting device info: $e');
          deviceId = const Uuid().v4();
        }
      }

      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  // Clear sync data (disconnect from sync)
  static Future<void> clearSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncIdKey);
    // Generate new sync ID
    await getSyncId();
  }
}
