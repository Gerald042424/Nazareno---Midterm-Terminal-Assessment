import 'package:cloud_firestore/cloud_firestore.dart';

class PreferencesHelper {
  static const String _defaultCity = 'Manila';
  static const String _weatherCityField = 'weatherCity';

  static Future<String> getWeatherCity(String? userId) async {
    if (userId == null) {
      return _defaultCity;
    }

    try {
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final dynamic city = doc.get(_weatherCityField);
        if (city is String && city.isNotEmpty) {
          return city;
        }
      }
    } catch (_) {
      // Fall back to default on error
    }

    return _defaultCity;
  }

  static Future<void> setWeatherCity(String userId, String city) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        _weatherCityField: city,
      }, SetOptions(merge: true));
    } catch (_) {
      // Silently fail
    }
  }

  static Future<void> clearWeatherCity(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        _weatherCityField: FieldValue.delete(),
      });
    } catch (_) {
      // Silently fail
    }
  }
}
