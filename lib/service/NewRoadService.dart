import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/appconstants.dart';

class NewRoadService {
  Future<List<List<LatLng>>> fetchNewRoads(
    String zoneName,
    String wardNo,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      throw Exception("City/Nagar Nigam not found. Please login again.");
    }

    final queryParams = <String, String>{
      "nagarNigam": nagarNigam.trim(),
      "zoneName": zoneName.trim(),
      "wardNo": wardNo.trim(),
    };

    String baseUrl = AppConstants.baseURL;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final url = Uri.parse(
      "$baseUrl/api/roads_mobile/all_new_road",
    ).replace(queryParameters: queryParams);

    debugPrint("📡 Fetching new roads from: $url");

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("📡 NEW ROAD RAW RESPONSE: ${response.body}");

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        debugPrint("❌ Backend response is not a Map. It is: ${decoded.runtimeType}");
        return [];
      }

      if (decoded['status'] != true) {
        debugPrint("⚠️ Backend returned status: ${decoded['status']}. Error: ${decoded['error']}");
        return [];
      }

      final List<dynamic> geometriesRaw = decoded['geometries'] ?? [];
      debugPrint("📦 Number of GeoJSON strings in 'geometries' list: ${geometriesRaw.length}");

      final List<List<LatLng>> allRoads = [];

      for (int i = 0; i < geometriesRaw.length; i++) {
        final geoJsonStr = geometriesRaw[i];
        if (geoJsonStr == null || geoJsonStr.toString().isEmpty) {
          debugPrint("⚠️ Geometry at index $i is null or empty");
          continue;
        }

        try {
          // backend returns GeoJSON as a String inside the list
          final Map<String, dynamic> geoJson = jsonDecode(geoJsonStr.toString());
          final String type = geoJson['type'] ?? 'Unknown';
          final dynamic coordinates = geoJson['coordinates'];

          debugPrint("🌐 Parsing geometry $i: type=$type");

          if (type == 'LineString' && coordinates is List) {
            final List<LatLng> points = coordinates.map<LatLng>((c) {
              return LatLng(
                (c[1] as num).toDouble(), // Latitude
                (c[0] as num).toDouble(), // Longitude
              );
            }).toList();
            if (points.length > 1) {
              allRoads.add(points);
              debugPrint("✅ Added LineString with ${points.length} points");
            }
          } else if (type == 'MultiLineString' && coordinates is List) {
            int subLines = 0;
            for (final line in coordinates) {
              if (line is List) {
                final List<LatLng> points = line.map<LatLng>((c) {
                  return LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  );
                }).toList();
                if (points.length > 1) {
                  allRoads.add(points);
                  subLines++;
                }
              }
            }
            debugPrint("✅ Added MultiLineString with $subLines sub-lines");
          } else {
            debugPrint("⚠️ Unsupported geometry type at index $i: $type");
          }
        } catch (e) {
          debugPrint("❌ Error parsing GeoJSON string at index $i: $e");
        }
      }

      debugPrint("🎯 Final count of allRoads parsed: ${allRoads.length}");
      return allRoads;
    } catch (e) {
      debugPrint("❌ Request error in fetchNewRoads: $e");
      rethrow;
    }
  }

  List<List<LatLng>> parseWKBHex(String hex) {
    final bytes = _hexToBytes(hex);
    final reader = _WKBReader(bytes);
    return reader.readGeometry();
  }

  Uint8List _hexToBytes(String hex) {
    final cleanHex = hex.trim();
    if (cleanHex.length % 2 != 0) {
      throw Exception("Invalid hex length");
    }
    final length = cleanHex.length ~/ 2;
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  List<LatLng> parseWKTLineString(String wkt) {
    String cleaned = wkt.trim();
    cleaned = cleaned
        .replaceFirst("LINESTRING", "")
        .replaceAll("(", "")
        .replaceAll(")", "")
        .trim();

    final parts = cleaned.split(",");
    final points = <LatLng>[];

    for (final part in parts) {
      final coords = part.trim().split(RegExp(r'\s+'));
      if (coords.length < 2) continue;

      final lon = double.tryParse(coords[0]);
      final lat = double.tryParse(coords[1]);

      if (lat != null && lon != null) {
        points.add(LatLng(lat, lon));
      }
    }
    return points;
  }

  List<List<LatLng>> parseWKTMultiLineString(String wkt) {
    String cleaned = wkt.trim().replaceFirst("MULTILINESTRING", "").trim();

    // remove outer brackets
    if (cleaned.startsWith("(")) cleaned = cleaned.substring(1);
    if (cleaned.endsWith(")")) cleaned = cleaned.substring(0, cleaned.length - 1);

    final lines = cleaned.split("),(");
    final allLines = <List<LatLng>>[];

    for (final line in lines) {
      final cleanLine = line.replaceAll("(", "").replaceAll(")", "").trim();
      final parts = cleanLine.split(",");
      final points = <LatLng>[];

      for (final part in parts) {
        final coords = part.trim().split(RegExp(r'\s+'));
        if (coords.length < 2) continue;

        final lon = double.tryParse(coords[0]);
        final lat = double.tryParse(coords[1]);

        if (lat != null && lon != null) {
          points.add(LatLng(lat, lon));
        }
      }

      if (points.length > 1) {
        allLines.add(points);
      }
    }
    return allLines;
  }
}

class _WKBReader {
  final Uint8List bytes;
  int offset = 0;

  _WKBReader(this.bytes);

  int readByte() {
    if (offset >= bytes.length) {
      throw Exception("Unexpected end of WKB while reading byte");
    }
    return bytes[offset++];
  }

  int readInt32(bool littleEndian) {
    if (offset + 4 > bytes.length) {
      throw Exception("Unexpected end of WKB while reading int32");
    }
    final byteData = ByteData.sublistView(bytes, offset, offset + 4);
    offset += 4;
    return littleEndian
        ? byteData.getInt32(0, Endian.little)
        : byteData.getInt32(0, Endian.big);
  }

  double readDouble(bool littleEndian) {
    if (offset + 8 > bytes.length) {
      throw Exception("Unexpected end of WKB while reading double");
    }
    final byteData = ByteData.sublistView(bytes, offset, offset + 8);
    offset += 8;
    return littleEndian
        ? byteData.getFloat64(0, Endian.little)
        : byteData.getFloat64(0, Endian.big);
  }

  List<List<LatLng>> readGeometry() {
    final byteOrder = readByte(); // 1 = LittleEndian, 0 = BigEndian
    final bool littleEndian = byteOrder == 1;

    int wkbType = readInt32(littleEndian);

    final bool hasSRID = (wkbType & 0x20000000) != 0;
    wkbType = wkbType & 0x0FFFFFFF;

    if (hasSRID) {
      readInt32(littleEndian); // skip SRID
    }

    if (wkbType == 2) {
      return [_readLineString(littleEndian)];
    }

    if (wkbType == 5) {
      return _readMultiLineString(littleEndian);
    }

    throw Exception("Unsupported WKB geometry type: $wkbType");
  }

  List<LatLng> _readLineString(bool littleEndian) {
    final numPoints = readInt32(littleEndian);
    final points = <LatLng>[];

    for (int i = 0; i < numPoints; i++) {
      final lon = readDouble(littleEndian);
      final lat = readDouble(littleEndian);
      points.add(LatLng(lat, lon));
    }
    return points;
  }

  List<List<LatLng>> _readMultiLineString(bool parentLittleEndian) {
    final numLines = readInt32(parentLittleEndian);
    final lines = <List<LatLng>>[];

    for (int i = 0; i < numLines; i++) {
      final subByteOrder = readByte();
      final bool subLittleEndian = subByteOrder == 1;

      int subType = readInt32(subLittleEndian);
      // Strip SRID/Z/M flags
      subType = subType & 0x0FFFFFFF;

      if (subType != 2) {
        throw Exception("Expected LINESTRING inside MULTILINESTRING, got type: $subType");
      }

      final line = _readLineString(subLittleEndian);
      if (line.length > 1) {
        lines.add(line);
      }
    }
    return lines;
  }
}
