import 'package:flutter/foundation.dart';

import '../../core/models/weather_model.dart';
import '../../core/services/weather_service.dart';
import '../../core/utils/app_constants.dart';

class WeatherProvider extends ChangeNotifier {
  WeatherProvider(this._weatherService);

  final WeatherService _weatherService;

  bool _isLoading = false;
  String? _errorMessage;
  WeatherModel? _weather;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  WeatherModel? get weather => _weather;

  Future<void> fetchWeather({
    String city = AppConstants.defaultWeatherCity,
    String? userId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _weatherService.fetchCurrentWeather(city: city, userId: userId);
    if (result.isSuccess) {
      _weather = result.data;
    } else {
      _errorMessage = result.error?.message;
    }

    _isLoading = false;
    notifyListeners();
  }
}
