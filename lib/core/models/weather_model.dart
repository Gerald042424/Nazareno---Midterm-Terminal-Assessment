class WeatherModel {
  const WeatherModel({
    required this.temperature,
    required this.condition,
    required this.locationName,
  });

  final double temperature;
  final String condition;
  final String locationName;

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final dynamic mainObj = json['main'];
    final dynamic weatherArr = json['weather'];
    final dynamic name = json['name'];

    final double temperature = (mainObj is Map<String, dynamic>)
        ? (mainObj['temp'] as num?)?.toDouble() ?? 0
        : 0;
    final String condition = (weatherArr is List && weatherArr.isNotEmpty)
        ? (weatherArr.first['main'] as String? ?? 'Unknown')
        : 'Unknown';

    return WeatherModel(
      temperature: temperature,
      condition: condition,
      locationName: name as String? ?? 'Unknown location',
    );
  }
}
