import 'package:shared_preferences/shared_preferences.dart';

class RoleGuard {
  static Future<String?> getRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("role");
  }

  static Future<bool> hasAccess(String requiredRole) async {
    String? role = await getRole();
    return role == requiredRole;
  }
}
