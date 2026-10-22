import 'package:json_annotation/json_annotation.dart';

/// Reads and writes timestamps as ISO 8601 strings in UTC.
///
/// Documents are shared between devices and the server, so local times are
/// converted to UTC on write and every parsed value is returned in UTC.
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}
