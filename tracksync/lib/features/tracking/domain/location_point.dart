class LocationPoint {
  const LocationPoint(
      {required this.id,
      required this.latitude,
      required this.longitude,
      required this.recordedAt,
      this.synced = false});

  final String id;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final bool synced;

  Map<String, Object?> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };

  factory LocationPoint.fromJson(Map<String, Object?> json) => LocationPoint(
        id: json['id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        synced: json['synced'] == 1,
      );
}
