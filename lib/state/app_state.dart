import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Текущий пользователь приложения: от его имени пишется история,
/// добавляются и удаляются комментарии.
class AppState extends ChangeNotifier {
  AppState(this._prefs) : currentUserId = _prefs.getInt(_key);

  final SharedPreferences _prefs;
  static const _key = 'current_user_id';

  int? currentUserId;

  Future<void> setCurrentUser(int? id) async {
    currentUserId = id;
    if (id == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setInt(_key, id);
    }
    notifyListeners();
  }
}
