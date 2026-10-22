import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:all_nagar_nigam_road_dir/service/DynamicDrainLegend.dart';
import 'package:all_nagar_nigam_road_dir/service/LocationService.dart';
import 'package:all_nagar_nigam_road_dir/utils/marker_icon_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'RoadConditionScreen.dart';
import 'models/asset_system.dart';
import 'service/DrainageService.dart';
import 'service/WardPolygonService.dart';
import 'Screens/drain_sceen/DrainUpdateFormScreen.dart';
import 'Screens/drain_sceen/NewRoadDrainFormScreen.dart';
import 'package:flutter/foundation.dart';



List<List<double>> parseLineCoords(String geojson) {
  try {
    // Decode the GeoJSON string
    final Map<String, dynamic> geo = jsonDecode(geojson);
    final String type = geo['type'];
    final coordsRaw = geo['coordinates'];

    final List<List<double>> coords = [];

    if (type == 'MultiLineString') {
      // Loop over the MultiLineString coordinates and parse them into LatLng pairs
      for (var line in coordsRaw) {
        if (line is List) {
          coords.addAll(line.map<List<double>>((c) => [c[0].toDouble(), c[1].toDouble()]).toList());
        } else {
          throw Exception("Invalid coordinate format in MultiLineString");
        }
      }
    } else if (type == 'LineString') {
      // If it's a LineString, just parse the coordinates directly
      if (coordsRaw is List) {
        coords.addAll(coordsRaw.map<List<double>>((c) => [c[0].toDouble(), c[1].toDouble()]).toList());
      } else {
        throw Exception("Invalid coordinate format in LineString");
      }
    } else {
      throw Exception("Unsupported GeoJSON type: $type");
    }

    // Log the parsed coordinates to see them
    debugPrint('Parsed GeoJSON coordinates: $coords');
    return coords;
  } catch (e) {
    debugPrint('Error parsing GeoJSON: $e');
    return [];
  }
}





// Update - 27/01/2026

class DrainageMapScreen extends StatefulWidget {
  static const routeName = '/drainage-map';

  final String? zoneName;
  final String wardNo;
  final String wardName;
  final String username; // ✅ ADD THIS

  const DrainageMapScreen({
    super.key,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
    required this.username, // ✅
  });

  @override
  State<DrainageMapScreen> createState() => _DrainageMapScreenState();
}

class _DrainageMapScreenState extends State<DrainageMapScreen> {
  // ===============================
  // 🆕 NEW ROAD CREATION (ADDED)
  // ===============================
  bool _isDrawingRoad = false;

  bool _hasAutoZoomed = false;

  bool _isCameraMoving = false;

  final LocationService locationService = LocationService();

  List<LatLng> _newRoadPoints = [];
  Polyline? _newRoadPreview;

  MapType _currentMapType = MapType.hybrid;
  double? _currentLat;
  double? _currentLng;

  GoogleMapController? _mapController;
  bool _locationGranted = false;

  // 🔹 UPDATE MODE
  bool _isUpdateMode = false;

  final WardPolygonService wardService = WardPolygonService();
  final DrainageService drainageService = DrainageService();

  Set<Polygon> _zonePolygons = {};
  Set<Polyline> _drainPolylines = {};

  bool _drainsLoaded = false;
  bool _mapReady = false;
  LatLngBounds? _pendingDrainBounds;

  Set<Polyline> _newDrainDottedPolylines = {};
  final Map<String, Set<Polyline>> _dottedCache = {};
  bool _isBusy = false;

  static const LatLng _kanpurCenter = LatLng(26.4499, 80.3319);
  static const LatLng _ghaziabadCenter = LatLng(28.6692, 77.4538);
  LatLng _fallbackCenter = _kanpurCenter;
  String _displayCityName = "Kanpur";
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadCityAndSetCenter();
    _checkLocationPermission();
    _fetchAutoLocation();
    loadZoneData(widget.wardName);
    loadDrainage();
    // loadNewCreatedDrains(); // ✅ ADD THIS
  }

  Future<void> _loadCityAndSetCenter() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString('city')?.toLowerCase() ?? "";

    if (city.contains("ghaziabad")) {
      setState(() {
        _fallbackCenter = _ghaziabadCenter;
        _displayCityName = "Ghaziabad";
      });
    } else {
      setState(() {
        _fallbackCenter = _kanpurCenter;
        _displayCityName = "Kanpur";
      });
    }
  }

  // Future<void> _fetchAutoLocation() async {
  //   try {
  //     final pos = await locationService.getCurrentLocation();
  //     if (!mounted) return;
  //
  //     setState(() {
  //       _currentLat = pos.latitude;
  //       _currentLng = pos.longitude;
  //     });
  //
  //     print("AUTO GPS → $_currentLat, $_currentLng");
  //   } catch (e) {
  //     // silent fail, app still usable
  //     print("Location error: $e");
  //   }
  // }

  Future<void> _fetchAutoLocation() async {
    try {
      final pos = await locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      });

      debugPrint("AUTO GPS → $_currentLat, $_currentLng");

      // 🔴 REMOVED automatic animateCamera to user location.
      // We want to prioritize the Ward area selected by the user.
      // User can still jump to their location using the "My Location" FAB.

    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  /* ---------------- LOCATION ---------------- */


  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (!mounted) return;

    setState(() {
      _locationGranted = status.isGranted;
    });

    if (!_locationGranted) {
      // Show a dialog asking for permission if denied
      _showLocationPermissionDialog();
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text("Please grant location permission to use this feature."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  List<LatLng> decimatePoints(List<LatLng> pts, int step) {
    if (pts.length <= 2 || step <= 1) return pts;

    final out = <LatLng>[];
    for (int i = 0; i < pts.length; i += step) {
      out.add(pts[i]);
    }
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }



  /* ---------------- DRAIN LOAD ---------------- */

  Future<void> loadDrainage() async {
    if (_isBusy) return; // ⛔ block re-entry
    _isBusy = true;

    try {
      final polylines = await drainageService.fetchDrainagePolylines(
        zoneName: widget.zoneName ?? "",
        wardName: widget.wardName,
        wardNo: widget.wardNo,
        onDrainTap: (id, isUpdated) => _onDrainTapped(id, isUpdated),
        isDrawingRoad: _isDrawingRoad,
      );

      // ===== STEP 1: MEASURE MAP LOAD SIZE =====
      final int totalPolylines = polylines.length;
      final int totalPoints = polylines.fold<int>(
        0,
            (sum, p) => sum + p.points.length,
      );

      debugPrint("MAP LOAD → polylines=$totalPolylines, points=$totalPoints");
      // =======================================

      // ===== SAFETY GUARD (ADD HERE) =====
      if (totalPoints > 120000) {
        debugPrint("⚠️ Too many points, skipping map render");
        _isBusy = false;
        return;
      }
      // =================================

      if (!mounted) return;

      if (polylines.isEmpty) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _showNoDrainDialog();
        }
        return;
      }
      // ✅ Yield UI thread once to avoid ANR
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      // Checking the fetched polylines' geometry for debugging
      for (final polyline in polylines) {
        debugPrint("Polyline ${polyline.polylineId.value}: ${polyline.points}");
      }

      // You can choose not to decimate the points for full details
      final reducedPolylines = polylines;  // Use full polylines without decimation

      final int reducedPoints = reducedPolylines.fold<int>(
        0,
            (sum, p) => sum + p.points.length,
      );

      debugPrint("MAP REDUCED → points=$reducedPoints (from $totalPoints)");

      setState(() {
        _drainPolylines = reducedPolylines;
      });

      // ---------- camera bounds ----------
      _pendingDrainBounds = _calculateDrainBounds(reducedPolylines);

      _drainsLoaded = true;

      Future.microtask(() {
        if (mounted) {
          loadNewCreatedDrains();
        }
      });

      if (_mapReady &&
          _mapController != null &&
          !_hasAutoZoomed &&
          _pendingDrainBounds != null &&
          !_isCameraMoving) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(_pendingDrainBounds!, 60),
        );

        // await _mapController!.animateCamera(
        //   CameraUpdate.newCameraPosition(
        //     CameraPosition(
        //       target: _kanpurCenter,
        //       zoom: await _mapController!.getZoomLevel(),
        //       bearing: 0,
        //       tilt: 0,
        //     ),
        //   ),
        // );

        if (_currentLat != null && _currentLng != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(_currentLat!, _currentLng!),  // Use current location
                zoom: await _mapController!.getZoomLevel(),  // Keep the current zoom level
                bearing: 0,
                tilt: 0,
              ),
            ),
          );
        } else {
          // Fallback based on city if location is not yet available
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _fallbackCenter,
                zoom: await _mapController!.getZoomLevel(),
                bearing: 0,
                tilt: 0,
              ),
            ),
          );
        }


        _hasAutoZoomed = true;
      }
    } catch (e) {
      debugPrint("loadDrainage failed: $e");
    } finally {
      _isBusy = false; // 🔓 ALWAYS unlock
    }
  }

  void _onDrainTapped(PolylineId id, bool isUpdated) {
    if (!_isUpdateMode) return;

    final int gid = int.parse(id.value);

    _showDrainExistConfirmDialog(gid, isUpdated);
  }

  void _showDrainExistConfirmDialog(int gid, bool isUpdated) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Drain"),
        content: const Text("Does this drain exist?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await drainageService.markDrainNotExist(
                gid,
                widget.username, // same username you already have
              );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Drain marked as NOT EXIST")),
              );

              await loadDrainage(); // refresh map
            },
            child: const Text("No"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            onPressed: () {
              Navigator.pop(context);

              // ✅ YES logic
              if (isUpdated) {
                _showAlreadyUpdatedDialog(gid);
              } else {
                _openDrainUpdateForm(gid);
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAlreadyUpdatedDialog(int gid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Already Updated"),
        content: const Text('This drain is already updated. Update again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            onPressed: () {
              Navigator.pop(context);
              _openDrainUpdateForm(gid);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openDrainUpdateForm(int gid) async {
    // 🔑 fetch full row by gid
    final drainData = await drainageService.fetchDrainDetails(gid);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrainUpdateFormScreen(
          drainData: drainData['data'],
          latitude: _currentLat,
          longitude: _currentLng,
        ),
      ),
    );

    if (!mounted) return;
    await loadDrainage();
  }

  /* ---------------- NO DRAIN DIALOG ---------------- */

  void _showNoDrainDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Drain Not Available"),
          content: const Text(
            "Drain is not available in this ward.\n\n"
            "Please select another ward or proceed to Drain work.\n\n"
            "इस वार्ड में ड्रेनेज उपलब्ध नहीं है।",
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _goToRoadCondition();
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  void _goToRoadCondition() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoadConditionScreen(system: AssetSystem.drainage),
      ),
    );
  }

  /* ---------------- WARD POLYGON ---------------- */

  // Future<void> loadZoneData(String? wardName) async {
  //   final result = await wardService.fetchWardPolygons(wardName: wardName);
  //   if (!mounted) return;
  //
  //   final polygons = result['polygons'] as List<Polygon>;
  //   final bounds = result['bounds'] as LatLngBounds?;
  //
  //   setState(() => _zonePolygons = polygons.toSet());
  //
  //   if (bounds != null && _mapController != null) {
  //     await _mapController!.animateCamera(
  //       CameraUpdate.newLatLngBounds(bounds, 50),
  //     );
  //   }
  // }

  LatLngBounds? _wardBounds;

  Future<void> loadZoneData(String? wardName) async {
    final result = await wardService.fetchWardPolygons(wardName: wardName);

    final List<Polygon> rawPolygons =
        result['polygons']; // Ensure this is a List<Polygon>
    final boundsData = result['bounds'];

    setState(() {
      // Convert List<Polygon> to Set<Polygon>
      _zonePolygons = rawPolygons
          .toSet(); // Convert List<Polygon> to Set<Polygon>

      // Ensure that boundsData is not null and properly set
      if (boundsData != null) {
        final minLat = boundsData['minLat'];
        final minLng = boundsData['minLng'];
        final maxLat = boundsData['maxLat'];
        final maxLng = boundsData['maxLng'];

        // Create the LatLngBounds with both southwest and northeast points
        _wardBounds = LatLngBounds(
          southwest: LatLng(minLat, minLng), // Southwest point
          northeast: LatLng(maxLat, maxLng), // Northeast point
        );
      }
    });

    if (!mounted) return;
    // Adjust the map view if _wardBounds is not null and _mapController is not null
    if (_wardBounds != null && _mapController != null) {
      _mapController!.moveCamera(
        CameraUpdate.newLatLngBounds(_wardBounds!, 50),
      );
    }
  }

  //----------------------------------- UI --------------------------------------------------------
  LatLngBounds _calculateDrainBounds(Set<Polyline> polylines) {
    double? minLat, maxLat, minLng, maxLng;

    for (final poly in polylines) {
      for (final p in poly.points) {
        minLat = (minLat == null) ? p.latitude : Math.min(minLat!, p.latitude);
        maxLat = (maxLat == null) ? p.latitude : Math.max(maxLat!, p.latitude);
        minLng = (minLng == null)
            ? p.longitude
            : Math.min(minLng!, p.longitude);
        maxLng = (maxLng == null)
            ? p.longitude
            : Math.max(maxLng!, p.longitude);
      }
    }

    if (minLat == null || minLng == null || maxLat == null || maxLng == null) {
      return LatLngBounds(southwest: _fallbackCenter, northeast: _fallbackCenter);
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  bool _isLegendVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          // ⬅️ Makes default back button white
          color: Colors.white,
        ),
        title: Center(
          child: Text(
            "$_displayCityName Drainage Network",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),

      body: Stack(
        children: [
          RepaintBoundary(
            child: GoogleMap(
              onCameraMoveStarted: () {
                _isCameraMoving = true;
              },
              onCameraIdle: () {
                _isCameraMoving = false;
              },

              // initialCameraPosition: const CameraPosition(
              //   target: _kanpurCenter,
              //   zoom: 14,
              //   bearing: 0, // ✅ NORTH
              //   tilt: 0, // ✅ NO TILT
              // ),

              initialCameraPosition: CameraPosition(
                target: _currentLat != null && _currentLng != null
                    ? LatLng(_currentLat!, _currentLng!)  // Current location
                    : _fallbackCenter,  // Fallback based on selected city
                zoom: 14,  // Adjust zoom level as needed
                bearing: 0,
                tilt: 0,
              ),


              onMapCreated: (controller) async {
                _mapController = controller;
                _mapReady = true;

                if (_drainsLoaded &&
                    _pendingDrainBounds != null &&
                    !_hasAutoZoomed) {
                  await _mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(_pendingDrainBounds!, 60),
                  );

                  _hasAutoZoomed = true;
                }

                Future.microtask(() {
                  if (!mounted) return;
                  loadNewCreatedDrains();
                });
              },

              onTap: (point) {
                // normal road drawing
                _handleNewRoadTap(point);
              },

              myLocationEnabled: _locationGranted && _currentLat != null,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,

              polygons: _zonePolygons,

              polylines: {
                ..._drainPolylines,

                ..._newDrainDottedPolylines,

                if (_newRoadPreview != null) _newRoadPreview!,
                // ✅ NEW CREATED DRAINS (DOTTED)
              },

              // update - 27/01/2026
              markers: {
                // startHandleMarker and endHandleMarker removed
              },

              mapType: _currentMapType,
            ),
          ),

          if (_isDrawingRoad) _drawModeControls(),
          Positioned(
            right: 8,
            bottom: 110,
            child: FloatingActionButton(
              heroTag: "drain_tools_fab",
              mini: true,
              backgroundColor: Colors.orange.shade700,
              child: const Icon(Icons.tune, color: Colors.white),
              onPressed: _openModeBottomSheet,
            ),
          ),
          Positioned(
            top: 20,
            right: 6,
            child: FloatingActionButton(
              heroTag: "drain_current_location_fab",
              backgroundColor: Colors.orange.shade700,
              mini: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  12,
                ), // 🟡 Slightly rounded rectangle
                side: BorderSide(
                  color: Colors.white,
                  width: 1,
                ), // Optional border
              ),

              // 👈 makes it smaller
              child: Icon(Icons.my_location, color: Colors.white),
              onPressed: () async {
                try {
                  final pos = await locationService.getCurrentLocation();

                  setState(() {
                    _currentLat = pos.latitude;
                    _currentLng = pos.longitude;
                  });

                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(pos.latitude, pos.longitude),
                        zoom: 18,
                        bearing: 0, // ✅ FORCE NORTH
                        tilt: 0, // ✅ REMOVE ROTATION
                      ),
                    ),
                  );
                } catch (_) {}
              },
            ),
          ),

          Positioned(
            bottom: 10, // Just below the filter toggle
            right: 6,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "drain_zoom_in_fab",
                  mini: true,
                  backgroundColor: Colors.orange.shade700,
                  onPressed: () async {
                    if (!_mapReady || _mapController == null || !mounted)
                      return;

                    try {
                      await _mapController!.animateCamera(
                        CameraUpdate.zoomIn(),
                      );
                    } catch (e) {
                      debugPrint("Zoom in failed: $e");
                    }
                  },

                  child: Icon(Icons.add, size: 25, color: Colors.white),
                ),
                // SizedBox(height: 5),
                FloatingActionButton(
                  heroTag: "drain_zoom_out_fab",
                  mini: true,
                  backgroundColor: Colors.orange.shade700,
                  onPressed: () async {
                    if (!_mapReady || _mapController == null || !mounted)
                      return;

                    try {
                      await _mapController!.animateCamera(
                        CameraUpdate.zoomOut(),
                      );
                    } catch (e) {
                      debugPrint("Zoom out failed: $e");
                    }
                  },

                  child: Icon(Icons.remove, size: 25, color: Colors.white),
                ),
              ],
            ),
          ),

          Positioned(
            top: 65,
            right: 6,
            child: FloatingActionButton(
              heroTag: "drain_base_map_layers_fab",
              onPressed: _showBaseMapOptions,
              tooltip: 'Change Base Map',
              backgroundColor: Colors.orange.shade700,
              mini: true,
              // 🟢 Reduces button size
              elevation: 6,
              // Adds shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  12,
                ), // 🟡 Slightly rounded rectangle
                side: BorderSide(
                  color: Colors.white,
                  width: 1,
                ), // Optional border
              ),
              child: Icon(
                Icons.layers,
                color: Colors.white,
                size: 20, // 🎯 Slightly smaller icon
              ),
            ),
          ),
          Positioned(
            top: 110, // 👈 below Change Base Map (which is at 65)
            right: 6,
            child: FloatingActionButton(
              heroTag: "dustbin",
              mini: true,
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white, width: 1),
              ),
              onPressed: _onDustbinPressed,
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          Positioned(
            bottom: 10,
            left: 6,
            child: GestureDetector(
              onTap: () {
                showSmallHint("Legend Button");

                setState(() {
                  _isLegendVisible = !_isLegendVisible;
                });
              },
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.legend_toggle, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_isLegendVisible)
            Positioned(
              bottom: 20,
              left: 60,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Legend",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...DynamicDrainLegend.getLegendItems(
                      buildLegendItem: _buildLegendItem,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDustbinPressed() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear / Delete"),
        content: const Text(
          "Do you want to clear the current operation?\n"
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),

            onPressed: () {
              Navigator.pop(context);

              _exitAllModes();
            },

            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 6,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _drawModeControls() {
    return Positioned(
      right: 6,
      bottom: 160, // above zoom buttons
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✔ / + / ❌ button
          FloatingActionButton(
            mini: true,
            heroTag: "drain_add_new_road_fab",
            backgroundColor: !_isDrawingRoad
                ? Colors.orange.shade700
                : (_newRoadPoints.length >= 2
                      ? Colors.green.shade700
                      : Colors.red),
            child: Icon(
              !_isDrawingRoad
                  ? Icons.add_road
                  : (_newRoadPoints.length >= 2 ? Icons.check : Icons.close),
              color: Colors.white,
            ),
            onPressed: () async {
              if (_newRoadPoints.length >= 2) {
                _openNewRoadForm();
                return;
              }
              _resetNewRoad();
            },
          ),

          const SizedBox(height: 6),

          // ↩ Undo
          FloatingActionButton(
            mini: true,
            heroTag: "drain_undo_new_road_fab",
            backgroundColor: Colors.black87,
            child: const Icon(Icons.undo, color: Colors.white),
            onPressed: _undoNewRoadPoint,
          ),
        ],
      ),
    );
  }

  void _openModeBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: _appOrange, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _appOrange.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                "Drain Tools",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _appOrange,
                ),
              ),

              const SizedBox(height: 14),

              _modeTile(
                icon: Icons.edit,
                title: "Update Drain",
                active: _isUpdateMode,
                onTap: _activateUpdateMode,
              ),

              _modeTile(
                icon: Icons.add_road,
                title: "Add New Drain",
                active: _isDrawingRoad,
                onTap: () async => await _activateNewDrainMode(),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _activateUpdateMode() {
    setState(() {
      _isUpdateMode = true;
      _isDrawingRoad = false;
    });
  }

  Future<void> _activateNewDrainMode() async {
    setState(() {
      // ❌ DO NOT clear existing new drains
      // _newDrainDottedPolylines.clear();

      _isUpdateMode = false;
      _isDrawingRoad = true;
    });
  }

  Future<void> _exitAllModes() async {
    setState(() {
      _isUpdateMode = false;
      _isDrawingRoad = false;
      _newRoadPoints.clear();
      _newRoadPreview = null;
    });
    // _setExistingDrainsTappable(true);   // ✅ restore

    // await loadDrainage();
  }

  final Color _appOrange = Colors.orange.shade700;

  Widget _modeTile({
    required IconData icon,
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _appOrange.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _appOrange, width: active ? 1.6 : 1.1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _appOrange, width: 1.2),
                color: active
                    ? _appOrange.withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              child: Icon(icon, color: _appOrange, size: 20),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _appOrange,
                ),
              ),
            ),

            if (active) Icon(Icons.check_circle, color: _appOrange, size: 20),
          ],
        ),
      ),
    );
  }

  void showSmallHint(String text) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 60,
        bottom: 180,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text, style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2)).then((_) {
      if (entry.mounted) entry.remove();
    });
  }

  void _showBaseMapOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 👈 makes it height-aware
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // limit height to avoid “RenderBox not laid out”
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade500.withValues(alpha: 0.95),
                        Colors.deepOrange.shade100.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        '🗺️ Select Base Map',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white24, thickness: 1),
                      const SizedBox(height: 6),
                      ..._mapOptions(context),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _mapOptions(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w500,
      fontSize: 15,
    );

    Widget _mapTile(String title, IconData icon, MapType type) {
      final bool selected = _currentMapType == type;
      return ListTile(
        leading: Icon(icon, color: selected ? Colors.white : Colors.white70),
        title: Text(title, style: textStyle),
        tileColor: selected
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          setState(() => _currentMapType = type);
          Navigator.pop(context);
        },
      );
    }

    return [
      _mapTile("Normal", Icons.map_rounded, MapType.normal),
      _mapTile("Satellite", Icons.satellite_alt_rounded, MapType.satellite),
      _mapTile("Terrain", Icons.terrain_rounded, MapType.terrain),
      _mapTile("Hybrid", Icons.layers_rounded, MapType.hybrid),
    ];
  }

  DateTime? _lastTapTs;

  // void _handleNewRoadTap(LatLng point) {
  //   if (_isCameraMoving) return;
  //   if (_isReshapeMode || _isUpdateMode) return;
  //   if (!_isDrawingRoad) return;
  //
  //   final now = DateTime.now();
  //   if (_lastTapTs != null &&
  //       now.difference(_lastTapTs!).inMilliseconds < 120) {
  //     return; // throttle fast taps
  //   }
  //   _lastTapTs = now;
  //
  //   setState(() {
  //     _newRoadPoints.add(point);
  //     _newRoadPreview = Polyline(
  //       polylineId: const PolylineId("new_road_preview"),
  //       // points: _newRoadPoints,
  //       points: List<LatLng>.from(_newRoadPoints),
  //       color: Colors.purpleAccent,
  //       width: 3,
  //     );
  //   });
  // }

  void _handleNewRoadTap(LatLng point) async {
    // Check if camera is moving or any drawing mode is active
    if (_isCameraMoving || _isUpdateMode || !_isDrawingRoad) return;

    // Prevent too fast taps (throttling)
    final now = DateTime.now();
    if (_lastTapTs != null && now.difference(_lastTapTs!).inMilliseconds < 120) {
      return; // Ignore rapid taps
    }
    _lastTapTs = now;

    // If more than one point, avoid adding points too quickly
    if (_newRoadPoints.length > 500) {
      // If there are already too many points, do not allow further points
      // Or you can decimate the existing points here
      return;
    }

    // Handle adding a new point
    _newRoadPoints.add(point);

    // Update polyline preview
    setState(() {
      // This ensures that only the new road preview is updated
      _newRoadPreview = Polyline(
        polylineId: const PolylineId("new_road_preview"),
        points: List<LatLng>.from(_newRoadPoints),  // Make sure to clone the list
        color: Colors.purpleAccent,
        width: 3,
      );
    });

    // Optional: Perform any background processing (e.g., geometry simplification)
    await Future.delayed(Duration.zero); // Allow UI to update, if needed

    // Ensure the polyline is within memory limits by decimating
    if (_newRoadPoints.length > 1000) {
      final decimatedPoints = decimatePoints(_newRoadPoints, 2);
      setState(() {
        _newRoadPreview = Polyline(
          polylineId: const PolylineId("new_road_preview"),
          points: List<LatLng>.from(decimatedPoints),
          color: Colors.purpleAccent,
          width: 3,
        );
      });
    }
  }


  void _undoNewRoadPoint() {
    if (_newRoadPoints.isEmpty) return;

    setState(() {
      _newRoadPoints.removeLast();

      if (_newRoadPoints.length < 2) {
        _newRoadPreview = null;
      } else {
        _newRoadPreview = Polyline(
          polylineId: const PolylineId("new_road_preview"),
          // points: _newRoadPoints,
          points: List<LatLng>.from(_newRoadPoints),

          color: Colors.purpleAccent,
          width: 5,
        );
      }
    });
  }

  // Future<void> _openNewRoadForm() async {
  //   if (_newRoadPoints.length < 2) return;
  //
  //   if (_currentLat == null || _currentLng == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Location not available yet")),
  //     );
  //     return;
  //   }
  //
  //   final wkt = _buildRoadWKT();
  //   if (wkt.isEmpty) return;
  //
  //   _isNavigating = true;
  //
  //   final bool? saved = await Navigator.push<bool>(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => NewRoadDrainFormScreen(
  //         geometry: wkt,
  //         zoneNo: widget.zoneName ?? "",
  //         zoneName: widget.zoneName ?? "",
  //         wardNo: widget.wardNo,
  //         wardName: widget.wardName,
  //         latitude: _currentLat!,
  //         longitude: _currentLng!,
  //       ),
  //     ),
  //   );
  //
  //   if (!mounted) return;
  //
  //   _isNavigating = false;
  //
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     if (!mounted) return;
  //
  //     _resetNewRoad();
  //
  //     // ✅ load ONLY if drain was actually saved
  //     if (saved == true) {
  //       await loadNewCreatedDrains();
  //     }
  //   });
  // }

  void _openNewRoadForm() async {
    if (_newRoadPoints.length < 2) return;

    if (_currentLat == null || _currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available yet")),
      );
      return;
    }

    final wkt = _buildRoadWKT();
    if (wkt.isEmpty) return;

    // Prevent navigation while busy
    if (_isNavigating) return;

    _isNavigating = true;

    try {
      final bool? saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => NewRoadDrainFormScreen(
            geometry: wkt,
            zoneNo: widget.zoneName ?? "",
            zoneName: widget.zoneName ?? "",
            wardNo: widget.wardNo,
            wardName: widget.wardName,
            latitude: _currentLat!,
            longitude: _currentLng!,
          ),
        ),
      );

      if (!mounted) return;

      _isNavigating = false;

      // Load new created drains only if the drain was successfully saved
      if (saved == true) {
        await loadNewCreatedDrains();
      }
    } catch (e) {
      debugPrint("Error in road form navigation: $e");
      _isNavigating = false;
    } finally {
      // Disable the drawing mode when returning from the form
      setState(() {
        _isDrawingRoad = false; // Disable road drawing mode
        _newRoadPoints.clear();
        _newRoadPreview = null;
      });
    }
  }


  // void _openNewRoadForm() async {
  //   if (_newRoadPoints.length < 2) return;
  //
  //   if (_currentLat == null || _currentLng == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Location not available yet")),
  //     );
  //     return;
  //   }
  //
  //   final wkt = _buildRoadWKT();
  //   if (wkt.isEmpty) return;
  //
  //   // Prevent navigation while busy
  //   if (_isNavigating) return;
  //
  //   _isNavigating = true;
  //
  //   try {
  //     final bool? saved = await Navigator.push<bool>(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => NewRoadDrainFormScreen(
  //           geometry: wkt,
  //           zoneNo: widget.zoneName ?? "",
  //           zoneName: widget.zoneName ?? "",
  //           wardNo: widget.wardNo,
  //           wardName: widget.wardName,
  //           latitude: _currentLat!,
  //           longitude: _currentLng!,
  //         ),
  //       ),
  //     );
  //
  //     if (!mounted) return;
  //
  //     _isNavigating = false;
  //
  //     // Load new created drains only if the drain was successfully saved
  //     if (saved == true) {
  //       await loadNewCreatedDrains();
  //     }
  //   } catch (e) {
  //     debugPrint("Error in road form navigation: $e");
  //     _isNavigating = false;
  //   }
  // }

  String _buildRoadWKT() {
    if (_newRoadPoints.length < 2) return "";

    final coords = _newRoadPoints
        .map((p) => "${p.longitude} ${p.latitude}")
        .join(", ");

    return "LINESTRING ($coords)";
  }

  void _resetNewRoad() async {
    setState(() {
      _isDrawingRoad = false;
      _newRoadPoints.clear();
      _newRoadPreview = null;
    });

    // await loadDrainage(); // ✅ RESTORE TAP BEHAVIOR
    // _setExistingDrainsTappable(true); // ✅ add this
  }

  bool _isLoadingNewDrains = false;

  List<LatLng> parseWKTToLatLngList(String wkt) {
    final List<LatLng> points = [];
    try {
      final uppercaseWkt = wkt.toUpperCase().trim();
      if (uppercaseWkt.contains("LINESTRING")) {
        final start = wkt.indexOf('(');
        final end = wkt.lastIndexOf(')');
        if (start != -1 && end != -1 && end > start) {
          String content = wkt.substring(start + 1, end).trim();
          content = content.replaceAll('(', '').replaceAll(')', '');
          final pointPairs = content.split(',');
          for (var pair in pointPairs) {
            final coords = pair.trim().split(RegExp(r'\s+'));
            if (coords.length >= 2) {
              final double? val1 = double.tryParse(coords[0]);
              final double? val2 = double.tryParse(coords[1]);
              if (val1 != null && val2 != null) {
                // In India, Longitude is ~70-90, Latitude is ~8-37
                if (val1 > val2) {
                  points.add(LatLng(val2, val1));
                } else {
                  points.add(LatLng(val1, val2));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error parsing WKT: $e");
    }
    return points;
  }

  List<LatLng> parseGeoJsonToLatLngList(dynamic geoSource) {
    if (geoSource == null) return [];

    final List<LatLng> points = [];
    try {
      // 1. If String, check if WKT or JSON
      if (geoSource is String) {
        final trimmed = geoSource.trim();
        final upper = trimmed.toUpperCase();
        if (upper.contains('LINESTRING')) {
          final wktPts = parseWKTToLatLngList(trimmed);
          if (wktPts.isNotEmpty) return wktPts;
        }

        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            final decodedPts = parseGeoJsonToLatLngList(decoded);
            if (decodedPts.isNotEmpty) return decodedPts;
          } catch (e) {
            debugPrint("Failed jsonDecode: $e");
          }
        }
      }

      // 2. If List
      if (geoSource is List) {
        for (var item in geoSource) {
          if (item is List && item.length >= 2) {
            final double? v1 = double.tryParse(item[0].toString());
            final double? v2 = double.tryParse(item[1].toString());
            if (v1 != null && v2 != null) {
              if (v1 > v2) {
                points.add(LatLng(v2, v1));
              } else {
                points.add(LatLng(v1, v2));
              }
            }
          } else if (item is Map) {
            final double? lat = double.tryParse((item['lat'] ?? item['latitude'])?.toString() ?? '');
            final double? lng = double.tryParse((item['lng'] ?? item['longitude'])?.toString() ?? '');
            if (lat != null && lng != null) {
              points.add(LatLng(lat, lng));
            }
          }
        }
        if (points.isNotEmpty) return points;
      }

      // 3. If Map / JSON Object
      if (geoSource is Map) {
        final map = Map<String, dynamic>.from(geoSource);

        if (map['type']?.toString().toLowerCase() == 'feature' && map.containsKey('geometry')) {
          final featurePts = parseGeoJsonToLatLngList(map['geometry']);
          if (featurePts.isNotEmpty) return featurePts;
        }

        if (map.containsKey('geometry') && map['geometry'] != null) {
          final innerPts = parseGeoJsonToLatLngList(map['geometry']);
          if (innerPts.isNotEmpty) return innerPts;
        }

        final String type = map['type']?.toString().toLowerCase() ?? '';
        final coordsRaw = map['coordinates'] ?? map['coords'];

        if ((type == 'linestring' || type == 'line') && coordsRaw is List) {
          for (var c in coordsRaw) {
            if (c is List && c.length >= 2) {
              final double? v1 = double.tryParse(c[0].toString());
              final double? v2 = double.tryParse(c[1].toString());
              if (v1 != null && v2 != null) {
                if (v1 > v2) {
                  points.add(LatLng(v2, v1));
                } else {
                  points.add(LatLng(v1, v2));
                }
              }
            }
          }
          if (points.isNotEmpty) return points;
        } else if (type == 'multilinestring' && coordsRaw is List) {
          for (var line in coordsRaw) {
            if (line is List) {
              for (var c in line) {
                if (c is List && c.length >= 2) {
                  final double? v1 = double.tryParse(c[0].toString());
                  final double? v2 = double.tryParse(c[1].toString());
                  if (v1 != null && v2 != null) {
                    if (v1 > v2) {
                      points.add(LatLng(v2, v1));
                    } else {
                      points.add(LatLng(v1, v2));
                    }
                  }
                }
              }
            }
          }
          if (points.isNotEmpty) return points;
        }
      }
    } catch (e) {
      debugPrint("Error in parseGeoJsonToLatLngList: $e");
    }

    // 4. Fallback Regex
    try {
      final str = geoSource.toString();
      final matches = RegExp(r'(-?\d+\.\d+)\s*[\s,]\s*(-?\d+\.\d+)').allMatches(str);
      for (final match in matches) {
        final double? num1 = double.tryParse(match.group(1) ?? '');
        final double? num2 = double.tryParse(match.group(2) ?? '');
        if (num1 != null && num2 != null) {
          if (num1 > num2) {
            points.add(LatLng(num2, num1));
          } else {
            points.add(LatLng(num1, num2));
          }
        }
      }
    } catch (e) {
      debugPrint("Regex fallback error: $e");
    }

    return points;
  }

  Future<void> loadNewCreatedDrains() async {
    if (!_mapReady || _isLoadingNewDrains) return;
    _isLoadingNewDrains = true;

    try {
      debugPrint("📡 Loading new created drains...");
      final result = await drainageService.fetchNewCreatedDrains(
        widget.zoneName ?? "",
        widget.wardNo,
      );

      // Handle both { data: [...] } and directly [...]
      final List<dynamic> rows = (result is List) 
          ? result 
          : (result['data'] ?? []);
      
      debugPrint("📡 Received ${rows.length} new created drains");

      // 🔥 HARD RESET: Clear previous cache
      _dottedCache.clear();

      final Set<Polyline> freshDottedPolylines = {};
      int polylineCount = 0;

      // Get the current zoom level
      final double zoom = await _mapController!.getZoomLevel();

      // Set decimation step based on zoom level
      int decimationStep;
      if (zoom >= 16) {
        decimationStep = 1;  // No decimation, high zoom
      } else if (zoom >= 14) {
        decimationStep = 3;  // Moderate decimation
      } else {
        decimationStep = 5;  // High decimation, low zoom
      }

      // Process newest drains first (highest gid first)
      final List<dynamic> sortedRows = List.from(rows);
      sortedRows.sort((a, b) {
        final int gidA = int.tryParse((a is Map ? a['gid'] : null)?.toString() ?? '0') ?? 0;
        final int gidB = int.tryParse((b is Map ? b['gid'] : null)?.toString() ?? '0') ?? 0;
        return gidB.compareTo(gidA);
      });

      for (final row in sortedRows) {
        if (polylineCount >= 250) break;

        final String gid = "new_${row['gid'] ?? row['id'] ?? polylineCount}";
        final dynamic geoSource = row['geojson'] ??
            row['geom'] ??
            row['geometry'] ??
            row['wkt_geom'] ??
            row['geomwkt'] ??
            row['wkt'] ??
            row['st_asgeojson'] ??
            row['st_astext'] ??
            row;

        if (geoSource == null) continue;

        final rawPoints = parseGeoJsonToLatLngList(geoSource);
        if (rawPoints.isEmpty) continue;

        // Yield UI thread periodically to prevent main thread blocking & heating
        if (polylineCount % 30 == 0) {
          await Future.delayed(Duration.zero);
          if (!mounted) return;
        }

        // 🔹 Build the polyline
        final Set<Polyline> built = _buildDottedPolyline(
          gid,
          List<LatLng>.from(rawPoints),
          color: Colors.blue,
        );

        _dottedCache[gid] = built;
        freshDottedPolylines.addAll(built);
        polylineCount++;
      }

      // Check if the widget is still mounted before updating the UI
      if (!mounted) return;

      debugPrint("📡 Displaying ${freshDottedPolylines.length} new created polylines");

      // Update map with new polylines
      setState(() {
        _newDrainDottedPolylines
          ..clear()
          ..addAll(freshDottedPolylines);
      });
    } catch (e) {
      debugPrint("❌ Failed to load new drains: $e");
    } finally {
      _isLoadingNewDrains = false;
    }
  }

  Set<Polyline> _buildDottedPolyline(
      String baseId,
      List<LatLng> points, {
        Color color = Colors.blue,
        int width = 5,
      }) {
    if (points.isEmpty) {
      debugPrint("Invalid Polyline Points: $baseId");
      return {};
    }

    return {
      Polyline(
        polylineId: PolylineId(baseId),
        points: points,
        color: color,
        width: width,
        consumeTapEvents: false,
      ),
    };
  }


  @override
  void dispose() {
    _isNavigating = true;
    _mapController?.dispose();
    _mapController = null;

    _dottedCache.clear();
    _drainPolylines.clear();
    _zonePolygons.clear();
    _newRoadPoints.clear();
    _newDrainDottedPolylines.clear();

    super.dispose();
  }
}



