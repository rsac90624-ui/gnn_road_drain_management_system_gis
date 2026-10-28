import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/appconstants.dart';

class DrainageService {
  // =========================================================
  // 🔹 FETCH DRAINS FOR MAP (WITH UPDATED STATUS)
  // =========================================================
  Future<Set<Polyline>> fetchDrainagePolylines({
    required String zoneName,
    required String wardName,
    required String wardNo,
    required bool isDrawingRoad,
    required Function(PolylineId, bool) onDrainTap,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? "";
    final token = prefs.getString('authToken');

    final uri = Uri.parse(
      "${AppConstants.baseURL}api/gha_drainage/map"
      "?nagarNigam=$nagarNigam"
      "&zoneName=$zoneName"
      "&wardName=$wardName"
      "&wardNo=$wardNo",
    );

    debugPrint("📡 FETCH DRAINAGE URL: $uri");

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );

    debugPrint("📡 DRAINAGE STATUS: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("❌ Error body: ${response.body}");
      throw Exception("Failed to load drainage data");
    }

    // Run JSON decode in background isolate to prevent ANR
    final decoded = await compute(jsonDecode, response.body);
    
    // Handle both List response and Map response with 'data' key
    final List drains = (decoded is List) ? decoded : (decoded['data'] ?? []);

    debugPrint("📡 TOTAL DRAINS RECEIVED: ${drains.length}");

    Set<Polyline> polylines = {};

    for (final drain in drains) {
      final gidRaw = drain['gid'];
      if (gidRaw == null) continue;

      final int gid = gidRaw is int
          ? gidRaw
          : int.tryParse(gidRaw.toString()) ?? -1;
      if (gid <= 0) continue;

      final bool isUpdated = drain['is_updated'] == true;
      final String? reshapeType = drain['reshape_type'];

      // Sometimes geometry is a string, sometimes it's already a map
      final dynamic geometrySource = drain['geometry'] ?? drain['geom'];
      if (geometrySource == null) continue;

      final Map<String, dynamic> geoJson = (geometrySource is String)
          ? json.decode(geometrySource)
          : Map<String, dynamic>.from(geometrySource);

      final String type = geoJson['type'];
      final coordinates = geoJson['coordinates'];

      // Process MultiLineString or LineString
      if (type == 'MultiLineString') {
        int segIndex = 0;
        for (final line in coordinates) {
          polylines.add(
            _buildPolyline(
              line,
              "$gid-$segIndex", // Unique ID for each segment
              gid,
              reshapeType,
              isUpdated,
              isDrawingRoad,
              onDrainTap,
            ),
          );
          segIndex++;
        }
      } else if (type == 'LineString') {
        polylines.add(
          _buildPolyline(
            coordinates,
            gid.toString(),
            gid,
            reshapeType,
            isUpdated,
            isDrawingRoad,
            onDrainTap,
          ),
        );
      }
    }

    return polylines;
  }


  Polyline _buildPolyline(
      List coordinates,
      String polylineId,
      int gid,
      String? reshapeType,
      bool isUpdated,
      bool isDrawingRoad,
      Function(PolylineId, bool) onDrainTap,
      ) {
    // Convert coordinates into LatLng points
    final points = coordinates.map<LatLng>((c) {
      return LatLng(
        (c[1] as num).toDouble(), // Latitude
        (c[0] as num).toDouble(), // Longitude
      );
    }).toList();

    // Set polyline color based on some condition
    Color lineColor = Colors.blue; // Default color
    if (reshapeType == "DECREASE") {
      lineColor = Colors.red;
    } else if (reshapeType == "INCREASE") {
      lineColor = Colors.orange;
    } else if (isUpdated) {
      lineColor = Colors.green;
    }

    return Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: lineColor,
      width: 3,
      consumeTapEvents: !isDrawingRoad,
      onTap: () {
        if (!isDrawingRoad) {
          onDrainTap(PolylineId(gid.toString()), isUpdated);
        }
      },
    );
  }


  Future<Map<String, dynamic>> fetchDrainDetails(int gid) async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? "";

    final uri = Uri.parse(
      "${AppConstants.baseURL}api/gha_drainage/drain/$gid"
      "?nagarNigam=$nagarNigam",
    );

    debugPrint("📡 FETCH DRAIN DETAILS URL: $uri");

    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
      },
    );

    debugPrint("📡 DRAIN DETAILS STATUS: ${res.statusCode}");

    if (res.statusCode != 200) {
      debugPrint("❌ Error body: ${res.body}");
      throw Exception("Failed to fetch drain details");
    }

    return json.decode(res.body);
  }

  Future<void> markDrainNotExist(int gid, String username) async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? "";

    final url = Uri.parse(
      "${AppConstants.baseURL}api/gha_drainage/mark-not-exist/$gid"
      "?nagarNigam=$nagarNigam",
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "X-User": username,
      },
    );

    debugPrint("MARK NOT EXIST URL: $url");
    debugPrint("STATUS: ${response.statusCode}");
    debugPrint("BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to mark drain as NOT EXIST → "
        "(${response.statusCode}) ${response.body}",
      );
    }
  }

  Future<dynamic> fetchNewCreatedDrains(
    String zoneNo,
    String wardNo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? "";

    final uri = Uri.parse(
      "${AppConstants.baseURL}api/gha_drainage/drain/new-created-list"
      "?zoneNo=${Uri.encodeComponent(zoneNo.trim())}"
      "&zoneName=${Uri.encodeComponent(zoneNo.trim())}"
      "&wardNo=${Uri.encodeComponent(wardNo.trim())}"
      "&nagarNigam=${Uri.encodeComponent(nagarNigam.trim())}",
    );

    debugPrint("📡 FETCH NEW DRAINS URL: $uri");

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      debugPrint("📡 NEW DRAINS STATUS: ${response.statusCode}");

      if (response.statusCode != 200) {
        debugPrint("❌ Error body: ${response.body}");
        throw Exception("Failed to load new created drains: ${response.statusCode}");
      }

      return await compute(jsonDecode, response.body);
    } catch (e) {
      debugPrint("❌ Request error in fetchNewCreatedDrains: $e");
      rethrow;
    }
  }
}

