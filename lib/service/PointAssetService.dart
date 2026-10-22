import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/appconstants.dart';

class PointAssetService {
  Future<List<Map<String, dynamic>>> fetchAssets(
    String assetType,
    String zoneName,
    String wardNo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';

    // Map asset names to endpoint slugs matching your Controller
    String endpoint;
    switch (assetType) {
      case "Manhole":
        endpoint = "api/manhole/list";
        break;
      case "Bus Stop":
        endpoint = "api/bus-stop/list";
        break;
      case "Green Median":
        endpoint = "api/green-median/list";
        break;
      case "Parking Area":
        endpoint = "api/parking/list";
        break;
      case "Road Signage":
        endpoint = "api/road-signage/list";
        break;
      case "Traffic Safety Features Layer":
        endpoint = "api/traffic-safety/list";
        break;
      case "Pavement Distress":
        endpoint = "api/pavement-distress/list";
        break;
      case "Public Toilet":
        endpoint = "api/public-toilet/list";
        break;
      case "Electric Pole":
        endpoint = "api/electric-pole/list";
        break;
      case "Transformer":
      case "Transformer/ RMU":
        endpoint = "api/transformer/list";
        break;
      case "Street Light":
        endpoint = "api/street-light/list";
        break;
      case "Telecom Box":
        endpoint = "api/telecom-box/list";
        break;
      default:
        return [];
    }

    String baseUrl = AppConstants.baseURL;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final url = Uri.parse("$baseUrl/$endpoint").replace(queryParameters: {
      "nagarNigam": nagarNigam,
      "zoneName": zoneName,
      "wardNo": wardNo,
    });

    debugPrint("📡 Fetching $assetType from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      debugPrint("📡 $assetType Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Run large JSON decode in background isolate to prevent ANR
        final decoded = await compute(jsonDecode, response.body);
        
        if (decoded is Map && decoded['status'] == true) {
          final List<dynamic> geometriesRaw = decoded['geometries'] ?? [];
          debugPrint("📦 $assetType raw geometries count: ${geometriesRaw.length}");

          return geometriesRaw.map((item) {
            // Case 1: Item is already a Map (e.g. Map<String, Object> from Spring)
            if (item is Map<String, dynamic>) return item;
            
            // Case 2: Item is a JSON String (e.g. ST_AsGeoJSON result)
            if (item is String) {
              try {
                return jsonDecode(item) as Map<String, dynamic>;
              } catch (e) {
                return <String, dynamic>{};
              }
            }
            return <String, dynamic>{};
          }).where((m) => m.isNotEmpty).toList();
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching $assetType: $e");
    }
    return [];
  }
}
