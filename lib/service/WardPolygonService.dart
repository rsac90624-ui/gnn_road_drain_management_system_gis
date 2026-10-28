import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/appconstants.dart';

class WardPolygonService {
  Future<Map<String, dynamic>> fetchWardPolygons({
    String? wardName,
    bool isEditing = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final nagarNigam =
        prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      throw Exception(
        "City/Nagar Nigam not found. Please login again.",
      );
    }

    final queryParams = <String, String>{
      'nagarNigam': nagarNigam.trim(),
    };

    if (wardName != null && wardName.trim().isNotEmpty) {
      queryParams['wardName'] = wardName.trim();
    }

    final uri = Uri.parse(
      "${AppConstants.baseURL}api/kanpur_boundary/boundaries",
    ).replace(
      queryParameters: queryParams,
    );

    debugPrint("📡 Fetching ward polygons from: $uri");

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    debugPrint("WARD BOUNDARY STATUS: ${response.statusCode}");
    debugPrint("WARD BOUNDARY BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load ward boundaries: ${response.statusCode}',
      );
    }

    final decoded = await compute(jsonDecode, response.body);

    if (decoded is! List) {
      throw Exception(
        "Invalid ward boundary response. Expected List.",
      );
    }

    final List<Polygon> polygons = [];

    double? minLat;
    double? maxLat;
    double? minLng;
    double? maxLng;

    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];

      if (item is! Map<String, dynamic>) {
        continue;
      }

      final geoJsonRaw = item['geojson'];

      if (geoJsonRaw == null) {
        continue;
      }

      final geoJson = geoJsonRaw is String
          ? jsonDecode(geoJsonRaw)
          : geoJsonRaw;

      final coordinates = geoJson['coordinates'];

      if (coordinates is! List) {
        continue;
      }

      for (int j = 0; j < coordinates.length; j++) {
        final polygon = coordinates[j];

        if (polygon is! List) {
          continue;
        }

        final List<LatLng> polygonPoints = [];

        for (final ring in polygon) {
          if (ring is! List) {
            continue;
          }

          for (final coord in ring) {
            if (coord is! List || coord.length < 2) {
              continue;
            }

            final lng = _toDouble(coord[0]);
            final lat = _toDouble(coord[1]);

            if (lat == null || lng == null) {
              continue;
            }

            polygonPoints.add(
              LatLng(lat, lng),
            );

            minLat = minLat == null
                ? lat
                : (lat < minLat ? lat : minLat);

            maxLat = maxLat == null
                ? lat
                : (lat > maxLat ? lat : maxLat);

            minLng = minLng == null
                ? lng
                : (lng < minLng ? lng : minLng);

            maxLng = maxLng == null
                ? lng
                : (lng > maxLng ? lng : maxLng);
          }
        }

        if (polygonPoints.length < 3) {
          continue;
        }

        polygons.add(
          Polygon(
            polygonId: PolygonId(
              'ward_${item['gid'] ?? i}_$j',
            ),
            points: polygonPoints,
            strokeWidth: 5,
            strokeColor: Colors.black,
            fillColor: isEditing
                ? Colors.blue.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.01),
          ),
        );
      }
    }

    LatLngBounds? bounds;

    if (minLat != null &&
        maxLat != null &&
        minLng != null &&
        maxLng != null) {
      bounds = LatLngBounds(
        southwest: LatLng(
          minLat,
          minLng,
        ),
        northeast: LatLng(
          maxLat,
          maxLng,
        ),
      );
    }

    debugPrint(
      "WARD POLYGONS COUNT: ${polygons.length}",
    );

    return {
      'polygons': polygons,
      'bounds': bounds,
    };
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}