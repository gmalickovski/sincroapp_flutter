import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/notifications/models/notification_model.dart';

class CheckUpdateService {
  final SupabaseService _supabaseService = SupabaseService();
  static const String _lastNotifiedVersionKey = 'last_notified_release_version';

  Future<void> checkForUpdates() async {
    try {
      // 1. Get Current App Version
      final packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // e.g. "1.2.13"

      // Fallback for web if package_info fails or returns empty in some envs
      if (currentVersion.isEmpty) {
        currentVersion = '1.0.0';
      }

      // 2. Check local preferences (already notified?)
      final prefs = await SharedPreferences.getInstance();
      final String? lastNotifiedVersion =
          prefs.getString(_lastNotifiedVersionKey);

      if (lastNotifiedVersion == currentVersion) {
        debugPrint(
            'System Update: Already notified for version $currentVersion');
        return;
      }

      // 3. Fetch Release Notes (Supabase Only)
      Map<String, dynamic>? notes;

      notes = await _supabaseService.getAppVersionDetails(currentVersion);

      if (notes == null) {
        debugPrint(
            'System Update: No release notes found for version $currentVersion');
        return;
      }

      // 4. User must be logged in
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 5. Create Notification
      final String title =
          notes['title'] ?? notes['label'] ?? 'Nova Atualização Disponível!';
      final String description =
          notes['description'] ?? 'Melhorias e correções no App.';
      final List<dynamic> details = notes['details'] ?? [];
      final String date = notes['date'] ??
          notes['release_date'] ??
          DateTime.now().toIso8601String();

      debugPrint(
          'System Update: Creating notification for version $currentVersion...');

      await _supabaseService.sendNotification(
        toUserId: user.id,
        type: NotificationType.system,
        title: title,
        body: description,
        relatedItemId: currentVersion,
        relatedItemType: 'app_version',
        metadata: {
          'version': currentVersion,
          'details': details,
          'date': date,
          'is_system_update': true,
        },
      );

      // 6. Update local preferences
      await prefs.setString(_lastNotifiedVersionKey, currentVersion);
      debugPrint('System Update: Notification created successfully.');
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }
}
