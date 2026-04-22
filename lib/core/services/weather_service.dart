import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/weather_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_result.dart';
import '../utils/preferences_helper.dart';

class WeatherService {
  WeatherService(this._httpClient);

  final http.Client _httpClient;

  Future<AppResult<WeatherModel>> fetchCurrentWeather({
    String? city,
    String? userId,
  }) async {
    final String apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
    final String cityToUse = city ?? await PreferencesHelper.getWeatherCity(userId);
    if (apiKey.isEmpty) {
      return AppResult.failure<WeatherModel>(
        const AppError(
          message: 'Weather API key is missing in .env file.',
          type: AppErrorType.validation,
        ),
      );
    }

    final Uri uri = Uri.parse(
      '${AppConstants.weatherApiBaseUrl}?q=$cityToUse&appid=$apiKey&units=metric',
    );

    try {
      final http.Response response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        return AppResult.failure<WeatherModel>(
          const AppError(
            message: 'Failed to fetch weather data.',
            type: AppErrorType.network,
          ),
        );
      }

      final dynamic parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        return AppResult.failure<WeatherModel>(
          const AppError(
            message: 'Invalid weather response.',
            type: AppErrorType.network,
          ),
        );
      }

      return AppResult.success<WeatherModel>(WeatherModel.fromJson(parsed));
    } catch (_) {
      return AppResult.failure<WeatherModel>(
        const AppError(
          message: 'Unable to load weather right now.',
          type: AppErrorType.network,
        ),
      );
    }
  }
}
