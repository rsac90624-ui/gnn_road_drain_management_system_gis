import 'dart:async';
import 'dart:convert';
import 'package:all_nagar_nigam_road_dir/utils/device_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:all_nagar_nigam_road_dir/RoadConditionScreen.dart';
import 'package:all_nagar_nigam_road_dir/RoadSignageFormScreen.dart';
import 'package:all_nagar_nigam_road_dir/TrafficSafetyFeaturesFormScreen.dart';
import 'constants/appconstants.dart';
import 'models/asset_system.dart';
import 'service/LocationService.dart';
import 'service/NewRoadService.dart';
import 'service/PointAssetService.dart';
import 'service/WardPolygonService.dart';
import 'service/dynamic_legend.dart';
import 'utils/ConfirmedRoadDatabase.dart';
import 'Screens/missing_road/MissingRoadFormScreen.dart';
import 'Screens/road_screen/NewRoadFormScreen.dart';
import 'Screens/road_screen/RoadUpdateScreen.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Welcomescreen extends StatefulWidget {
  final List<String> roadAgeCategory;

  final String? zoneName;
  final String wardNo;
  final String wardName;

  const Welcomescreen({
    super.key,
    required this.roadAgeCategory,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<Welcomescreen> createState() => WelcomescreenState();
}

class WelcomescreenState extends State<Welcomescreen> {

  String? _trafficSafetyGeometryType;

  List<LatLng> _trafficSafetyLinePoints = [];
  Polyline? _trafficSafetyLinePreview;
  // late final Map<String, dynamic>? initialFormData;

  // 🆕 ROAD CREATION FEATURE START
  bool _isDrawingRoad = false; // Whether drawing mode is active
  List<LatLng> _newRoadPoints = []; // Temporarily holds drawn road points
  Polyline? _newRoadPreview; // Polyline being drawn
  // 🆕 ROAD CREATION FEATURE END

  // 🆕 ROAD Selection FEATURE START
  bool _isSelectingRoad = false; // Whether road selection mode is active
  // 🆕 ROAD Selection FEATURE End

  // 🆕 ROAD Update FEATURE START
  bool _isUpdatingRoad = false; // Whether road update mode is active

  bool _isMarkingParking = false;
  bool _isMarkingToilets = false;
  bool _isMarkingElectricPoles = false;
  bool _isMarkingTransformers = false;

  List<LatLng> _parkingPoints = [];
  List<LatLng> _toiletPoints = [];
  List<LatLng> _electricPolePoints = [];
  List<LatLng> _transformerPoints = [];

  Map<String, dynamic>? _pendingRoadData;
  Map<String, dynamic>? _pendingRoadFormData;

  List<List<LatLng>> _selectedRoadSegments = [];

  Timer? _cameraIdleTimer;

  // 🆕 ROAD Update FEATURE End

  final Completer<GoogleMapController> _controller = Completer();
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  int? _selectedYear;
  Set<Polygon> _zonePolygons = {};

  String? _selectedZone;
  String? _selectedWard;

  int _roadCount = 0;
  List<dynamic> connectedRoadData = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  bool _isFilterPanelVisible = false;
  List<String> _selectedPriority = []; // must be List<String>

  List<String> _roadNames = [];
  List<String> _filteredRoadNames = [];
  Set<Polyline> newRoadPolylines = {};

  bool _showSearchBar = false;

  MapType _currentMapType = MapType.hybrid;
  final GlobalKey mapKey = GlobalKey();

  bool _isPriorityFilterActive = false;

  Set<String> _selectedRoadIds = {}; // To store selected road IDs
  List<Map<String, dynamic>> _selectedRoadData = []; // Store full road info

  double? _currentLat;
  double? _currentLng;
  double _currentZoomLevel = 11.0;
  BitmapDescriptor? _selectionIcon;

  bool _isExtending = false;
  int _extendTapCount = 0;
  LatLng? _selectedPointLocation;
  bool _isPointMarking = false;
  String? selectedPointAsset;
  
  Set<Polyline> _searchHighlights = {};
  Set<Polyline> _missingRoadPolylines = {};
  bool _missingRoadVisible = false;
  bool _isFabExpanded = false;
  bool _newRoadConfirmShown = false;

  //----------------------------------------- Service Classes ------------------------------------------------------------------------------------------------
  final LocationService locationService = LocationService();
  final wardService = WardPolygonService();

  final NewRoadService newRoadService = NewRoadService();
  final PointAssetService pointAssetService = PointAssetService();

  Set<Marker> _manholeMarkers = {};
  Set<Marker> _busStopMarkers = {};
  Set<Polygon> _parkingAreaPolygons = {};
  Set<Marker> _roadSignageMarkers = {};
  Set<Marker> _trafficSafetyMarkers = {};
  Set<Polyline> _trafficSafetyLines = {};
  Set<Marker> _pavementDistressMarkers = {};
  Set<Polygon> _pavementDistressPolygons = {};
  Set<Marker> _toiletMarkers = {};
  Set<Marker> _electricPoleMarkers = {};
  Set<Marker> _transformerMarkers = {};
  Set<Marker> _streetLightMarkers = {};
  Set<Marker> _telecomBoxMarkers = {};

  //----------------------------------------------------------------------------------------------------------------------------------------------------------

  // Initialize selectedRoadConditions with predefined values
  Set<String> selectedRoadConditions = {
    'Roads between 1 to 5 years',
    'Roads greater than 5 years',
  };

  @override
  void initState() {
    super.initState();
    _checkMiuiBatteryRestriction();
    _selectedZone = widget.zoneName;
    _selectedWard = widget.wardNo;
    // Initialize selectedRoadConditions with the passed roadAgeCategory value
    selectedRoadConditions = Set<String>.from(
      widget.roadAgeCategory,
    ); // Directly use the list

    // loadZoneData(widget.wardName);
    debugPrint("Initial road names: $_roadNames"); // Debugging

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.wardName.trim().isNotEmpty) {
        loadZoneData(widget.wardName.trim());
      }
      locationService.getCurrentLocation();
      loadNewRoads(); // 👈 ADD THIS
      loadAllPointAssets(); // 👈 ADD THIS FOR PERSISTENT ASSETS
      _initSelectionIcon();
    });

    // Debugging: Print the values coming through
    debugPrint("zoneName: ${widget.zoneName}");
    debugPrint("wardNo: ${widget.wardNo}");
    debugPrint("wardName: ${widget.wardName}");
    debugPrint("roadAgeCategory: ${widget.roadAgeCategory}");
  }

  Future<void> _initSelectionIcon() async {
    _selectionIcon = await _getSmallCircleIcon(Colors.red);
    if (mounted) setState(() {});
  }

  Future<void> _checkMiuiBatteryRestriction() async {
    final isXiaomiDevice = await DeviceUtils.isXiaomi();

    if (!isXiaomiDevice || !mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('miui_battery_hint_shown') ?? false;

    if (alreadyShown) {
      return;
    }

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Important performance setting'),
          content: const Text(
            "On Redmi, Xiaomi and POCO phones, battery optimization may stop "
            "map rendering and background operations.\n\n"
            "Please set Battery usage to 'No restrictions' for smooth operation.\n\n"
            "This is required only once.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('miui_battery_hint_shown', true);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setBool('miui_battery_hint_shown', true);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                await _openAppBatterySettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAppBatterySettings() async {
    final info = await PackageInfo.fromPlatform();
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:${info.packageName}',
    );
    await intent.launch();
  }

  @override
  void dispose() {
    // Cancel any ongoing asynchronous operations like timers
    _cameraIdleTimer?.cancel();

    // Dispose of any controllers
    _searchController.dispose();
    reasonController.dispose();

    // Clear other resources to avoid memory leaks
    _polylines.clear();
    _markers.clear();
    newRoadPolylines.clear();
    _missingRoadPolylines.clear();
    _searchHighlights.clear();
    _selectedRoadSegments.clear();
    _labelCache.clear();

    super.dispose();
  }

  //-------------------------------------- Showing current location ----------------------------------------------------------------

  void onMaterialSelected(String material) {
    setState(() {
      _activeMaterial = material; // ✅ single source of truth
    });

    _fetchPolylineDataFromBounds(); // redraw roads
  }

  void clearMaterialHighlight() {
    setState(() {
      _activeMaterial = null; // ✅ reset material mode
    });

    _fetchPolylineDataFromBounds();
  }

  Future<void> loadZoneData(String? wardName) async {
    final result = await wardService.fetchWardPolygons(wardName: wardName);
    final polygons = result['polygons'] as List<Polygon>;
    final bounds = result['bounds'] as LatLngBounds?;

    if (mounted) {
      setState(() {
        _zonePolygons = polygons.toSet();
      });
    }

    if (bounds != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 🛡️ Safety checks before using GoogleMapController
        if (!_controller.isCompleted) return;
        final controller = await _controller.future;
        if (controller == null) return;

        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      });
    }
  }

  void _undoLastNewRoadPoint() {
    if (_newRoadPoints.isEmpty) return;

    setState(() {
      _newRoadPoints.removeLast();

      // allow confirm dialog again after undo
      _newRoadConfirmShown = false;

      if (_newRoadPoints.length < 2) {
        _newRoadPreview = null;
      } else {
        _newRoadPreview = Polyline(
          polylineId: const PolylineId("new_road"),
          points: _newRoadPoints,
          color: Colors.purpleAccent,
          width: 5,
        );
      }
    });
  }

  //------------------------------------------ confirmation popup dialog -----------------------------------------------------------

  // void _showRoadInfoPopup(
  //   BuildContext context,
  //   Map<String, dynamic> roadData, {
  //   bool isAlreadyConfirmed = false,
  //   String? confirmedAt,
  // }) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (BuildContext context) {
  //       return SafeArea(
  //         child: SingleChildScrollView(
  //           child: ConstrainedBox(
  //             constraints: BoxConstraints(
  //               maxHeight: MediaQuery.of(context).size.height * 0.9,
  //             ),
  //             child: Padding(
  //               padding: EdgeInsets.only(
  //                 left: 16,
  //                 right: 16,
  //                 top: 20,
  //                 bottom: MediaQuery.of(context).viewInsets.bottom,
  //               ),
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Align(
  //                     alignment: Alignment.topRight,
  //                     child: IconButton(
  //                       icon: Icon(Icons.close, color: Colors.orange.shade700),
  //                       onPressed: () {
  //                         Navigator.pop(context);
  //                         _deselectRoadOnMap(roadData);
  //                       },
  //                     ),
  //                   ),
  //                   Center(
  //                     child: Text(
  //                       "📍 Road Information",
  //                       style: TextStyle(
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.orange,
  //                       ),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 16),
  //                   Text("🆔 Road ID: ${roadData['road_id'] ?? 'N/A'}"),
  //                   Text("📛 Name: ${roadData['road_name'] ?? 'N/A'}"),
  //                   Text("📍 Zone: ${roadData['zone_name'] ?? 'N/A'}"),
  //                   Text("🏘️ Ward: ${roadData['ward_no'] ?? 'N/A'}"),
  //                   Text("🛣️ Category: ${roadData['category'] ?? 'N/A'}"),
  //                   Text("📏 Length (m): ${roadData['length_met'] ?? 'N/A'}"),
  //                   Text("🏗️ Condition: ${roadData['condition'] ?? 'N/A'}"),
  //                   Text(
  //                     "📅 Year of Construction: ${roadData['yoc'] ?? 'N/A'}",
  //                   ),
  //                   Text("🏥 Hospital : ${roadData['hospital'] ?? 'N/A'}"),
  //                   Text("🏦 Bank : ${roadData['bank_atm'] ?? 'N/A'}"),
  //                   Text("🏫 School : ${roadData['educationa'] ?? 'N/A'}"),
  //                   const SizedBox(height: 16),
  //                   Row(
  //                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                     children: [
  //                       TextButton.icon(
  //                         onPressed: () {
  //                           Navigator.pop(context);
  //                           _deselectRoadOnMap(roadData);
  //                         },
  //                         icon: const Icon(Icons.clear, color: Colors.red),
  //                         label: const Text(
  //                           "Clear",
  //                           style: TextStyle(
  //                             color: Colors.red,
  //                             fontWeight: FontWeight.w600,
  //                           ),
  //                         ),
  //                       ),
  //                       if (isAlreadyConfirmed)
  //                         Column(
  //                           crossAxisAlignment: CrossAxisAlignment.center,
  //                           children: [
  //                             Text(
  //                               "✅ Already confirmed on:",
  //                               style: TextStyle(
  //                                 color: Colors.green.shade700,
  //                                 fontWeight: FontWeight.bold,
  //                               ),
  //                             ),
  //                             Text(
  //                               confirmedAt ?? "Unknown time",
  //                               style: const TextStyle(
  //                                 fontSize: 12,
  //                                 color: Colors.black87,
  //                               ),
  //                             ),
  //                             const SizedBox(height: 6),
  //                             ElevatedButton.icon(
  //                               onPressed: null,
  //                               icon: const Icon(
  //                                 Icons.check_circle_outline,
  //                                 color: Colors.white,
  //                               ),
  //                               label: const Text("Confirmed"),
  //                               style: ElevatedButton.styleFrom(
  //                                 backgroundColor: Colors.grey,
  //                                 disabledBackgroundColor: Colors.grey,
  //                               ),
  //                             ),
  //                           ],
  //                         )
  //                       else
  //                         ElevatedButton(
  //                           onPressed: () {
  //                             showDialog(
  //                               context: context,
  //                               builder: (BuildContext dialogContext) {
  //                                 return AlertDialog(
  //                                   title: const Text("Confirm Selection"),
  //                                   content: const Text(
  //                                     "Are you sure you want to confirm this road selection?",
  //                                   ),
  //                                   actions: [
  //                                     TextButton(
  //                                       child: const Text("No"),
  //                                       onPressed: () {
  //                                         Navigator.pop(dialogContext);
  //                                         Navigator.pop(context);
  //                                         _deselectRoadOnMap(roadData);
  //                                       },
  //                                     ),
  //                                     TextButton(
  //                                       child: const Text("Yes"),
  //                                       onPressed: () {
  //                                         Navigator.pop(dialogContext);
  //                                         _confirmRoadSelection(roadData);
  //                                         Navigator.pop(context);
  //                                       },
  //                                     ),
  //                                   ],
  //                                 );
  //                               },
  //                             );
  //                           },
  //                           style: ElevatedButton.styleFrom(
  //                             backgroundColor: Colors.orange.shade700,
  //                             shape: RoundedRectangleBorder(
  //                               borderRadius: BorderRadius.circular(10),
  //                             ),
  //                           ),
  //                           child: const Text(
  //                             "Confirm Road Selection",
  //                             style: TextStyle(
  //                               color: Colors.white,
  //                               fontSize: 15,
  //                             ),
  //                           ),
  //                         ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  //---------------------------------------------- Deselect the Road Data -------------------------------------------------------------
  void _deselectRoadOnMap(Map<String, dynamic> roadData) {
    final roadId = roadData['road_id'].toString();

    setState(() {
      _selectedRoadIds.remove(roadId); // ⬅️ This line was missing
      _selectedRoadData.removeWhere(
        (item) => item['road_id'].toString() == roadId,
      );
    });

    // 🔁 Refresh the polylines to apply color change
    _fetchPolylineDataFromBounds();
  }

  //------------------------------------------ fetch new road ------------------------------------------------------------------------------------

  loadNewRoads() async {
    try {
      final roads = await newRoadService.fetchNewRoads(
        widget.zoneName ?? "",
        widget.wardNo,
      );

      debugPrint("🧭 WELCOME: Total new roads fetched: ${roads.length}");

      final Set<Polyline> newPolylines = {};
      int id = 1;

      for (var road in roads) {
        if (road.isEmpty) continue;
        
        debugPrint("🛣️ New road polyline $id has ${road.length} points");
        
        newPolylines.add(
          Polyline(
            polylineId: PolylineId("new_road_persistent_$id"),
            points: road,
            width: 6,
            color: Colors.orange.shade800,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            consumeTapEvents: !_isDrawingRoad,
            zIndex: 10, // Ensure it's on top
          ),
        );
        id++;
      }

      if (mounted) {
        setState(() {
          newRoadPolylines = newPolylines;
          debugPrint("🗺️ Map updated with ${newRoadPolylines.length} persistent new roads");
        });
      }
    } catch (e) {
      debugPrint("❌ Error in loadNewRoads: $e");
    }
  }

  //--------------------------------------------- Fetch PolyLine Data ------------------------------------------------------------------
  Polyline? _highlightedPolyline;

  List<Map<String, dynamic>> _allRoadsData = [];

  String? _activeMaterial; // 'CC', 'BOE', 'Kachcha', etc.

  static const Map<String, Color> materialColors = {
    'Bitumen': Color(0xFF3A4F7A),
    'CC': Colors.grey,
    'Interlocking': Colors.orange,
    'BOE': Colors.blueGrey,
    'Kachcha': Colors.brown,
  };

  Future<void> _fetchPolylineDataFromBounds() async {
    if (_missingRoadVisible) return;
    if (!_controller.isCompleted) return;

    final controller = await _controller.future;
    if (controller == null) return;

    final queryParams = <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();

    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    debugPrint("🛣 ROAD API NAGAR NIGAM: $nagarNigam");

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      debugPrint("❌ city/nagarNigam not found in SharedPreferences");
      return;
    }

    queryParams['nagarNigam'] = nagarNigam.trim();

    final z = widget.zoneName?.trim();
    if (z != null && z.isNotEmpty) queryParams['zoneName'] = [z];

    if (widget.wardName.isNotEmpty) {
      queryParams['wardName'] = [widget.wardName];
    }

    if (widget.roadAgeCategory.isNotEmpty) {
      queryParams['roadAgeCategory'] = widget.roadAgeCategory
          .map((e) => e.toLowerCase().replaceAll(' ', '_'))
          .toList();
    }

    final uri = buildUriWithMultipleValues(
      '${AppConstants.baseURL}api/roads_mobile/filter',
      queryParams,
    );

    try {
      final response = await http.get(uri, headers: await _authHeaders());

      debugPrint("🛣 ROAD API URL: $uri");
      debugPrint("🛣 ROAD API STATUS: ${response.statusCode}");
      debugPrint("🛣 ROAD API BODY: ${response.body}");
      if (response.statusCode != 200) return;

      final List data = json.decode(response.body);
      
      bool wardChanged = false;
      if (data.isNotEmpty) {
        final firstRoad = data.first;
        final newZone = firstRoad['zone_name']?.toString() ?? firstRoad['zoneName']?.toString();
        final newWard = firstRoad['ward_no']?.toString() ?? firstRoad['wardNo']?.toString();
        
        if (newWard != _selectedWard || newZone != _selectedZone) {
          wardChanged = true;
        }

        Set<String> ownershipSet = {};
        for (final item in data) {
          final ownership = item['ownership']?.toString();
          if (ownership != null && ownership.isNotEmpty) {
            ownershipSet.add(ownership);
          }
        }

        setState(() {
          _selectedZone = newZone;
          _selectedWard = newWard;
          _allRoadsData = data.cast<Map<String, dynamic>>();
          
          if (wardChanged) {
            loadAllPointAssets(); // 👈 ONLY REFRESH IF WARD CHANGED
          }
        });
      }

      await _renderPolylines(data);
    } catch (e) {
      debugPrint('❌ Error fetching polylines: $e');
    }
  }

  Future<void> _renderPolylines(List data) async {
    Set<Polyline> polylineSet = {};
    int roadCount = 0;

    for (final item in data) {
      final String? wkt = item['wkt_geom'];
      if (wkt == null) continue;

      final roadId = item['road_id'].toString();

      Color lineColor = Colors.green;
      final condition = item['condition']?.toString();
      if (condition == 'Poor') lineColor = Colors.red;
      if (condition == 'Moderate') lineColor = Colors.yellow;

      final material = item['material']?.toString();
      if (_activeMaterial != null) {
        if (material == null || material.toLowerCase() != _activeMaterial!.toLowerCase()) {
          continue;
        }
        lineColor = materialColors[_activeMaterial!] ?? lineColor;
      }

      if (item['is_confirmed'] == true) lineColor = Colors.blueAccent.shade700;
      if (_selectedRoadIds.contains(roadId)) lineColor = Colors.orange.shade700;

      final double? rowMeter = double.tryParse(
        item['row_meter']?.toString() ?? '',
      );

      if (rowMeter != null && rowMeter >= 12) {
        lineColor = Colors.cyanAccent.shade700;
      }

      if (item['is_updated'] == true) lineColor = Colors.deepPurpleAccent;

      final segments = await compute<String, List<List<LatLng>>>(parseWKTToSegments, wkt);

      int segIndex = 0;
      for (final segment in segments) {
        final points = decimatePoints(segment, _currentZoomLevel);
        polylineSet.add(
          Polyline(
            polylineId: PolylineId('${roadId}_seg_$segIndex'),
            points: points,
            width: 4,
            color: lineColor,
            consumeTapEvents: !(_isDrawingRoad || _isPointMarking),
            onTap: () async {
              if (_isDrawingRoad) return;
              if (!_isSelectingRoad && !_isUpdatingRoad) return;

              if (_isUpdatingRoad) {
                _openRoadUpdateForm(item);
                return;
              }

              if (_isSelectingRoad) {
                setState(() {
                  if (_selectedRoadIds.contains(roadId)) {
                    _selectedRoadIds.remove(roadId);
                  } else {
                    _selectedRoadIds.add(roadId);
                  }
                });
                _renderPolylines(_allRoadsData); // 👈 LOCAL REDRAW, NO NETWORK
                // _showRoadInfoPopup(context, item);
              }
            },
          ),
        );
        segIndex++;
      }
      roadCount++;
    }

    if (mounted) {
      setState(() {
        _polylines = polylineSet;
        _roadCount = roadCount;
      });
    }
  }

  String formatDateTime(String dateTimeString) {
    final DateTime dt = DateTime.parse(dateTimeString);
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.year}";
  }

  // Projection of tap onto segment AB (in lat/lng plane)
  LatLng _closestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.latitude;
    final ay = a.longitude;
    final bx = b.latitude;
    final by = b.longitude;
    final px = p.latitude;
    final py = p.longitude;

    final dx = bx - ax;
    final dy = by - ay;

    final len2 = dx * dx + dy * dy;
    if (len2 == 0.0) return a;

    double t = ((px - ax) * dx + (py - ay) * dy) / len2;
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;

    final projX = ax + t * dx;
    final projY = ay + t * dy;

    return LatLng(projX, projY);
  }

  Uri buildUriWithMultipleValues(
    String baseUrl,
    Map<String, dynamic> queryParams,
  ) {
    final buffer = StringBuffer(baseUrl);
    if (!baseUrl.contains('?')) buffer.write('?');

    final queryParts = <String>[];

    queryParams.forEach((key, value) {
      if (value == null) return;

      if (value is List) {
        for (var v in value) {
          if (v != null && v.toString().isNotEmpty) {
            queryParts.add(
              '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(v.toString())}',
            );
          }
        }
      } else {
        if (value.toString().isNotEmpty) {
          queryParts.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value.toString())}',
          );
        }
      }
    });

    buffer.write(queryParts.join('&'));
    return Uri.parse(buffer.toString());
  }

  List<LatLng> parseWKTToLatLng(String wkt) {
    final regex = RegExp(r'MULTILINESTRING\(\((.*?)\)\)');
    final match = regex.firstMatch(wkt);
    if (match == null) return [];

    final coordinates = match.group(1)?.split(',') ?? [];
    List<LatLng> points = [];

    // Loop through each coordinate and create LatLng
    for (var coord in coordinates) {
      final parts = coord.split(' ');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[1]);
        final lon = double.tryParse(parts[0]);
        if (lat != null && lon != null) {
          points.add(LatLng(lat, lon));
        }
      }
    }

    return points;
  }

  void _startParkingMarking(
      Map<String, dynamic> roadData,
      Map<String, dynamic> formData,
      List<Map<String, dynamic>> existingPoints,
      ) {
    setState(() {
      _disableAllModes();
      _isMarkingParking = true;
      _pendingRoadData = Map<String, dynamic>.from(roadData);
      _pendingRoadFormData = Map<String, dynamic>.from(formData);
      _parkingPoints = existingPoints.map((point) {
        return LatLng(
          (point['latitude'] as num).toDouble(),
          (point['longitude'] as num).toDouble(),
        );
      }).toList();
    });
    showSmallHint("Tap on map to mark parking points");
  }

  void _startToiletMarking(Map<String, dynamic> roadData, Map<String, dynamic> formData, List<Map<String, dynamic>> existingPoints) {
    setState(() {
      _disableAllModes();
      _isMarkingToilets = true;
      _pendingRoadData = Map<String, dynamic>.from(roadData);
      _pendingRoadFormData = Map<String, dynamic>.from(formData);
      _toiletPoints = existingPoints.map((point) => LatLng((point['latitude'] as num).toDouble(), (point['longitude'] as num).toDouble())).toList();
    });
    showSmallHint("Tap on map to mark toilets");
  }



  void _startTransformerMarking(Map<String, dynamic> roadData, Map<String, dynamic> formData, List<Map<String, dynamic>> existingPoints) {
    setState(() {
      _disableAllModes();
      _isMarkingTransformers = true;
      _pendingRoadData = Map<String, dynamic>.from(roadData);
      _pendingRoadFormData = Map<String, dynamic>.from(formData);
      _transformerPoints = existingPoints.map((point) => LatLng((point['latitude'] as num).toDouble(), (point['longitude'] as num).toDouble())).toList();
    });
    showSmallHint("Tap on map to mark transformers");
  }

  Future<void> _openRoadUpdateForm(Map<String, dynamic> roadData) async {
    // if (await DeviceUtils.blockIfRooted(context)) return;

    // if (await DeviceUtils.isEmulator()) {
    //   showDialog(
    //     context: context,
    //     builder: (_) => const AlertDialog(
    //       content: Text("Road update not allowed on emulator."),
    //     ),
    //   );
    //   return;
    // }

    // 🔥 Extract ownership from already fetched data
    Set<String> ownershipSet = {};

    for (final item in _allRoadsData) {
      final ownership = item['ownership']?.toString();
      if (ownership != null && ownership.isNotEmpty) {
        ownershipSet.add(ownership);
      }
    }

    // ✅ ADD THIS
    final ownershipList = ownershipSet.toList()..sort();
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => RoadUpdateScreen(
    //       roadData: roadData,
    //       latitude: _currentLat,
    //       longitude: _currentLng,
    //       roadAgeCategory:
    //           widget.roadAgeCategory, // Pass the required parameters
    //       zoneName: widget.zoneName,
    //       wardNo: widget.wardNo,
    //       wardName: widget.wardName,
    //       ownershipList: ownershipList,
    //     ),
    //   ),
    // );

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => RoadUpdateScreen(
          roadData: roadData,
          latitude: _currentLat,
          longitude: _currentLng,
          roadAgeCategory: widget.roadAgeCategory,
          zoneName: widget.zoneName,
          wardNo: widget.wardNo,
          wardName: widget.wardName,
          ownershipList: ownershipList,
        ),
      ),
    );

    if (result == null) {
      return;
    }



    if (result['action'] == 'mark_transforme') {
      _startTransformerMarking(
        Map<String, dynamic>.from(result['roadData']),
        Map<String, dynamic>.from(result['formData']),
        List<Map<String, dynamic>>.from(result['transformerPoints'] ?? []),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // Navigate to RoadAgeScreen when back button is pressed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RoadConditionScreen(system: AssetSystem.road),
          ),
        );
      },
      child: buildMainUI(),
    );
  }

  bool _isLegendVisible = false;

  Widget _buildLegendItem(Color color, String label) {
    // Determine if it's a point asset based on the label or just show both line and dot
    bool isPoint = ["Manhole", "Bus Stop", "Road Signage", "Public Toilet", "Electric Pole", "Transformer", "Street Light", "Telecom Box", "Parking Area", "Pavement Distress"].contains(label);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 30,
            alignment: Alignment.centerLeft,
            child: isPoint
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  )
                : Container(
                    width: 25,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // void _showReshapeConfirmDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text("Confirm Reshape"),
  //       content: Text("Replace the old road shape with this new shape?"),
  //       actions: [
  //         TextButton(
  //           child: Text("Cancel"),
  //           onPressed: () {
  //             Navigator.pop(context);
  //             setState(() {
  //               // Reshape state reset
  //               _reshapePoints.clear();
  //               _reshapePreview = null;
  //               _isReshapeDrawing = false;
  //               _isReshaping = false;
  //               _selectedRoadIdForReshape = null;
  //
  //               // REMOVE highlighted road
  //               _highlightedPolyline = null; // custom highlight polyline
  //               _selectedPolylineId = null; // clears yellow search highlight
  //               _waitingForReshapeStartPoint = false;
  //               _reshapeConfirmShown = false;
  //
  //               // Restore default polylines (remove pink highlight from reshape)
  //               _fetchPolylineDataFromBounds(); // reload fresh map lines
  //             });
  //           },
  //         ),
  //
  //         TextButton(
  //           child: Text("Confirm"),
  //           onPressed: () {
  //             Navigator.pop(context);
  //
  //             final wkt = _reshapeWKT(); // your reshaped geometry WKT
  //             debugPrint(
  //               "-------------------reshape data --------------------------------------------------",
  //             );
  //             debugPrint(_selectedRoadData.toString());
  //
  //             if (_selectedRoadData.isEmpty) {
  //               debugPrint("DEBUG → _selectedRoadData EMPTY");
  //               debugPrint(
  //                 "DEBUG → _selectedRoadIdForReshape = $_selectedRoadIdForReshape",
  //               );
  //               debugPrint("DEBUG → _lastTappedMapPoint = $_lastTappedMapPoint");
  //               debugPrint(
  //                 "DEBUG → isReshape = $_isReshaping, isDrawing = $_isReshapeDrawing",
  //               );
  //
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text("No road details found. Cannot reshape."),
  //                 ),
  //               );
  //               return;
  //             }
  //
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (_) => ReshapeFormScreen(
  //                   geometry: wkt,
  //                   roadId: _selectedRoadData[0]["road_id"],
  //                   existingData: _selectedRoadData[0],
  //                   latitude: _currentLat,
  //                   longitude: _currentLng,
  //                   roadAgeCategory:
  //                       widget.roadAgeCategory, // Pass the required parameters
  //                   zoneName: widget.zoneName,
  //                   wardNo: widget.wardNo,
  //                   wardName: widget.wardName,
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // String _reshapeWKT() {
  //   return "LINESTRING (${_reshapePoints.map((p) => "${p.longitude} ${p.latitude}").join(", ")})";
  // }

  // void _calculateRoadLength(LatLng start, LatLng end) async {
  //   double distanceInMeters = await Geolocator.distanceBetween(
  //     start.latitude,
  //     start.longitude,
  //     end.latitude,
  //     end.longitude,
  //   );
  //
  //   setState(() {
  //     _roadLength = distanceInMeters; // Store the distance
  //   });
  //
  //   // Display the distance in the UI
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text("Road Length: ${_roadLength.toStringAsFixed(2)} meters"),
  //     ),
  //   );
  // }

  List<Widget> _getDynamicLegendItems() {
    return DynamicLegend.getLegendItems(
      selectedPriority: _selectedPriority,
      selectedMaterial: _activeMaterial, // 👈 PASS THIS
      buildLegendItem: _buildLegendItem,
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

    Future.delayed(Duration(seconds: 2)).then((_) => entry.remove());
  }

  final LocationService _locationService = LocationService();

  Future<void> _moveToUserLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;

      // ✅ STORE LOCATION HERE
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });

      final controller = await _controller.future;
      if (!mounted) return;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          18,
        ),
      );
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  void _showMaterialSelector() {
    final materials = <String>{
      ..._allRoadsData
          .map((r) => r['material']?.toString())
          .where((m) => m != null && m!.isNotEmpty)
          .cast<String>(),
    }.toList()..sort();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Material Filter",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: materials.map((material) {
                  final bool selected = _activeMaterial == material;

                  return ChoiceChip(
                    label: Text(material),
                    selected: selected,
                    selectedColor: Colors.cyan.shade200,
                    onSelected: (_) {
                      onMaterialSelected(material);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              if (_activeMaterial != null)
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text("Clear Material Filter"),
                    onPressed: () {
                      clearMaterialHighlight();
                      Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }


  Set<Marker> _buildParkingMarkers() {
    return _parkingPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return Marker(
        markerId: MarkerId('parking_marker_$index'),
        position: point,
        infoWindow: InfoWindow(title: 'Parking Point ${index + 1}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      );
    }).toSet();
  }

  Set<Marker> _buildToiletMarkers() {
    return _toiletPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      return Marker(
        markerId: MarkerId('toilet_marker_$index'),
        position: point,
        infoWindow: InfoWindow(title: 'Toilet ${index + 1}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );
    }).toSet();
  }



  Set<Marker> _buildTransformerMarkers() {
    return _transformerPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      return Marker(
        markerId: MarkerId('transformer_marker_$index'),
        position: point,
        infoWindow: InfoWindow(title: 'Transformer ${index + 1}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
      );
    }).toSet();
  }

  Widget buildMainUI() {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            key: mapKey,
            // padding: EdgeInsets.only(bottom: 120, right: 20),
            onTap: (LatLng tappedPoint) async {
              if (_isPointMarking) {
                // =================================================
                // TRAFFIC SAFETY FEATURES
                // =================================================
                if (selectedPointAsset ==
                    "Traffic Safety Features Layer") {

                  // ---------------- POINT ----------------
                  if (_trafficSafetyGeometryType ==
                      "Point") {
                    setState(() {
                      _selectedPointLocation =
                          tappedPoint;
                    });

                    showSmallHint(
                      "Point marked. Press Confirm.",
                    );

                    return;
                  }

                  // ---------------- LINE ----------------
                  if (_trafficSafetyGeometryType ==
                      "Line") {
                    setState(() {
                      _trafficSafetyLinePoints.add(
                        tappedPoint,
                      );

                      if (_trafficSafetyLinePoints.length >=
                          2) {
                        // _trafficSafetyLinePreview =
                        //     Polyline(
                        //       polylineId:
                        //       const PolylineId(
                        //         "traffic_safety_line",
                        //       ),
                        //       points:
                        //       _trafficSafetyLinePoints,
                        //       color: Colors.redAccent,
                        //       width: 5,
                        //     );

                        _trafficSafetyLinePreview = Polyline(
                          polylineId: const PolylineId(
                            "traffic_safety_line",
                          ),
                          points: List<LatLng>.from(
                            _trafficSafetyLinePoints,
                          ),
                          color: Colors.redAccent,
                          width: 5,
                        );
                      }
                    });

                    showSmallHint(
                      "Point ${_trafficSafetyLinePoints.length} added",
                    );

                    return;
                  }
                }



                // =================================================
                // PARKING AREA (POLYGON)
                // =================================================
                if (selectedPointAsset == "Parking Area") {
                  setState(() {
                    _parkingAreaPolygonPoints.add(tappedPoint);
                    if (_parkingAreaPolygonPoints.length >= 3) {
                      _parkingAreaPolygonPreview = Polygon(
                        polygonId: const PolygonId("parking_area_polygon"),
                        points: List<LatLng>.from(_parkingAreaPolygonPoints),
                        fillColor: Colors.blueAccent.withValues(alpha: 0.3),
                        strokeColor: Colors.blueAccent,
                        strokeWidth: 3,
                      );
                    }
                  });
                  showSmallHint("Point ${_parkingAreaPolygonPoints.length} added");
                  return;
                }

                // =================================================
                // NORMAL POINT ASSETS LIKE ROAD SIGNAGE
                // =================================================
                setState(() {
                  _selectedPointLocation =
                      tappedPoint;
                });

                showSmallHint(
                  "${selectedPointAsset ?? 'Point'} marked. Press Confirm.",
                );

                return;
              }

              if (_isDrawingRoad) {
                LatLng pointToAdd;

                if (_newRoadPoints.isEmpty) {
                  // ✅ snap ONLY first point
                  pointToAdd = await _snapToNearestRoad(
                    tappedPoint,
                    maxMeters: 20,
                  );
                  if (!mounted) return;
                } else {
                  // ✅ free draw after start
                  pointToAdd = tappedPoint;
                }

                setState(() {
                  _newRoadPoints.add(pointToAdd);

                  _newRoadPreview = Polyline(
                    polylineId: const PolylineId("new_road"),
                    color: Colors.purpleAccent,
                    width: 5,
                    points: _newRoadPoints,
                  );
                });

                // -------------------------------
                // NEW EXTEND LIMIT LOGIC HERE
                // -------------------------------
                if (_isExtending) {
                  _extendTapCount++;

                  if (_extendTapCount >= 3) {
                    _isExtending = false; // stop extending
                    _showConfirmOrExtendDialog(); // show popup again
                  }
                  return;
                }

                if (_newRoadPoints.length > 3 &&
                    !_newRoadConfirmShown &&
                    !_isExtending) {
                  _newRoadConfirmShown = true;
                  _showConfirmOrExtendDialog();
                }
              }
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(20.5937, 78.9629), // India center
              zoom: 11,
            ),
            onMapCreated: (controller) async {
              _controller.complete(controller);
              await _moveToUserLocation(); // 👈 Jump to user location
            },

            onCameraMove: (position) {
              _currentZoomLevel = position.zoom;
            },
            onCameraIdle: () {
              // if (_isDrawingRoad || _missingRoadVisible) return;
              if (_isDrawingRoad ||
                  _missingRoadVisible ||
                  _isPointMarking) {
                return;
              }

              _cameraIdleTimer?.cancel();
              _cameraIdleTimer = Timer(const Duration(milliseconds: 600), () {
                if (mounted) _fetchPolylineDataFromBounds();
              });
            },

            markers: {
              ..._markers,
              if (_currentZoomLevel > 15.5) ...{
                ..._manholeMarkers,
                ..._busStopMarkers,
                ..._roadSignageMarkers,
                ..._trafficSafetyMarkers,
                ..._pavementDistressMarkers,
                ..._toiletMarkers,
                ..._electricPoleMarkers,
                ..._transformerMarkers,
                ..._streetLightMarkers,
                ..._telecomBoxMarkers,
              },

              if (_isMarkingParking) ..._buildParkingMarkers(),

              if (_isMarkingToilets) ..._buildToiletMarkers(),
              if (_isMarkingTransformers) ..._buildTransformerMarkers(),

              // Point Data marker
              if (_isPointMarking && _selectedPointLocation != null)
                Marker(
                  markerId: const MarkerId('point_data_selected_marker'),
                  position: _selectedPointLocation!,
                  icon: _selectionIcon ?? BitmapDescriptor.defaultMarker,
                  infoWindow: InfoWindow(
                    title: selectedPointAsset ?? "Point Asset",
                  ),
                ),
            },

            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: _currentMapType,
            polygons: {
              ..._zonePolygons,
              ..._parkingAreaPolygons,
              ..._pavementDistressPolygons,



              if (_isPointMarking &&
                  selectedPointAsset == "Parking Area" &&
                  _parkingAreaPolygonPreview != null)
                _parkingAreaPolygonPreview!,
            }, // Merge both sets // Display updated ward boundaries

            zoomControlsEnabled: false,

            polylines: {
              ..._polylines,
              ...newRoadPolylines,
              ..._trafficSafetyLines,

              if (_missingRoadVisible) ..._missingRoadPolylines,
              if (_highlightedPolyline != null) _highlightedPolyline!,
              if (_searchHighlights.isNotEmpty) ..._searchHighlights,

              if (_isDrawingRoad && _newRoadPreview != null) _newRoadPreview!,
              if (_isPointMarking &&
                  selectedPointAsset ==
                      "Traffic Safety Features Layer" &&
                  _trafficSafetyGeometryType ==
                      "Line" &&
                  _trafficSafetyLinePreview != null)
                _trafficSafetyLinePreview!,
            },
          ),
          if (_isMarkingParking)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _parkingPoints.isEmpty
                          ? null
                          : () {
                        setState(() {
                          _parkingPoints.removeLast();
                        });
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text("Undo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _finishParkingMarking,
                      icon: const Icon(Icons.check),
                      label: Text("Done (${_parkingPoints.length})"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isMarkingToilets)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toiletPoints.isEmpty ? null : () => setState(() => _toiletPoints.removeLast()),
                      icon: const Icon(Icons.undo),
                      label: const Text("Undo"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _finishToiletMarking,
                      icon: const Icon(Icons.check),
                      label: Text("Done (${_toiletPoints.length})"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          if (_isMarkingTransformers)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _transformerPoints.isEmpty ? null : () => setState(() => _transformerPoints.removeLast()),
                      icon: const Icon(Icons.undo),
                      label: const Text("Undo"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _finishTransformerMarking,
                      icon: const Icon(Icons.check),
                      label: Text("Done (${_transformerPoints.length})"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          // =====================================================
// TRAFFIC SAFETY LINE UNDO
// =====================================================
          if (_isPointMarking &&
              selectedPointAsset == "Traffic Safety Features Layer" &&
              _trafficSafetyGeometryType == "Line" &&
              _trafficSafetyLinePoints.isNotEmpty)
            Positioned(
              bottom: 145,
              right: 20,
              child: FloatingActionButton(
                heroTag: "traffic_safety_line_undo_main",
                mini: true,
                backgroundColor: Colors.grey.shade800,
                tooltip: "Undo last point",
                onPressed: () {
                  setState(() {
                    _trafficSafetyLinePoints.removeLast();

                    if (_trafficSafetyLinePoints.length < 2) {
                      _trafficSafetyLinePreview = null;
                    } else {
                      _trafficSafetyLinePreview = Polyline(
                        polylineId: const PolylineId(
                          "traffic_safety_line",
                        ),
                        points: List<LatLng>.from(
                          _trafficSafetyLinePoints,
                        ),
                        color: Colors.redAccent,
                        width: 5,
                      );
                    }
                  });
                },
                child: const Icon(
                  Icons.undo,
                  color: Colors.white,
                ),
              ),
            ),
          // =====================================================
          // PARKING AREA POLYGON UNDO
          // =====================================================
          if (_isPointMarking &&
              selectedPointAsset == "Parking Area" &&
              _parkingAreaPolygonPoints.isNotEmpty)
            Positioned(
              bottom: 145,
              right: 20,
              child: FloatingActionButton(
                heroTag: "parking_area_polygon_undo_main",
                mini: true,
                backgroundColor: Colors.blueGrey,
                onPressed: () {
                  setState(() {
                    _parkingAreaPolygonPoints.removeLast();
                    if (_parkingAreaPolygonPoints.length < 3) {
                      _parkingAreaPolygonPreview = null;
                    } else {
                      _parkingAreaPolygonPreview = Polygon(
                        polygonId: const PolygonId("parking_area_polygon"),
                        points: _parkingAreaPolygonPoints.toList(),
                        fillColor: Colors.blueAccent.withValues(alpha: 0.3),
                        strokeColor: Colors.blueAccent,
                        strokeWidth: 3,
                      );
                    }
                  });
                },
                child: const Icon(
                  Icons.undo,
                  color: Colors.white,
                ),
              ),
            ),
          // =====================================================
          // POINT DATA CONFIRM / CANCEL
          // =====================================================
          if (_isPointMarking)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cancelPointMarking,
                      icon: const Icon(Icons.close),
                      label: const Text("Cancel"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canConfirmPointAsset()
                          ? _confirmPointAsset
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text("Confirm"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // if (_isMeasuring && _measurementPoints.isNotEmpty)
          //   Positioned(
          //     bottom: 260,
          //     right: 6,
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 12,
          //         vertical: 8,
          //       ),
          //       decoration: BoxDecoration(
          //         color: Colors.black87,
          //         borderRadius: BorderRadius.circular(10),
          //       ),
          //       child: Text(
          //         "Distance: ${_roadLength.toStringAsFixed(2)} m",
          //         style: const TextStyle(color: Colors.white),
          //       ),
          //     ),
          //   ),

          // if (_isMeasuring && _measurementPoints.length > 1)
          //   Positioned(
          //     bottom: 220,
          //     right: 6,
          //     child: FloatingActionButton(
          //       mini: true,
          //       backgroundColor: Colors.black,
          //       child: const Icon(Icons.undo, color: Colors.white),
          //       onPressed: () {
          //         setState(() {
          //           _measurementPoints.removeLast();
          //           _roadLength = _calculateCumulativeDistance(
          //             _measurementPoints,
          //           );
          //
          //           if (_measurementPoints.length < 2) {
          //             _measurePolyline = null;
          //           } else {
          //             _measurePolyline = Polyline(
          //               polylineId: const PolylineId("measure_line"),
          //               points: _measurementPoints,
          //               width: 4,
          //               color: Colors.blueAccent,
          //             );
          //           }
          //         });
          //       },
          //     ),
          //   ),

      if (_isDrawingRoad && _newRoadPoints.length > 1)
            Positioned(
              bottom: 220,
              right: 6,
              child: FloatingActionButton(
                heroTag: "undo_new_road",
                mini: true,
                backgroundColor: Colors.purple,
                tooltip: "Undo last road point",
                onPressed: _undoLastNewRoadPoint,
                child: const Icon(Icons.undo, color: Colors.white),
              ),
            ),

          Positioned(
            bottom: 120,
            right: 6,
            child: FloatingActionButton(
              heroTag: "material_filter_fab",
              mini: true,
              backgroundColor: _activeMaterial != null
                  ? materialColors[_activeMaterial] ?? Colors.cyan.shade700
                  : Colors.orange.shade700,
              child: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showMaterialSelector,
            ),
          ),

          Positioned(
            top: 80,
            right: 6,
            child: FloatingActionButton(
              heroTag: "current_location_fab",
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
                showSmallHint("Current Location");

                bool serviceEnabled =
                    await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  await Geolocator.openLocationSettings();
                  return;
                }

                LocationPermission permission =
                    await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }

                if (permission == LocationPermission.deniedForever) {
                  return;
                }

                final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          18,
        ),
      );
    },
  ),
),
          Positioned(
            top: 80,
            left: 10,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) {
                    _roadNames.clear();
                    _searchController.clear();
                  } else {
                    _roadNames.clear();
                    _filteredRoadNames.clear();
                    _searchController.clear();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                // Makes it round
                padding: EdgeInsets.all(12),
                backgroundColor: Colors.orange.shade700,
                // Background color
                elevation: 6,
                shadowColor: Colors.black54,
              ),
              child: Icon(
                _showSearchBar ? Icons.close : Icons.search,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          // 📄 List of Road Matches
          // 🔍 Search Bar
          if (_showSearchBar)
            Positioned(
              top: 80,
              left: 10,
              right: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for roads...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _fetchRoadNames(""); // Show full list again
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onTap: () {
                    _fetchRoadNames(""); // Fetch and show all names on tap
                  },
                  onChanged: (value) {
                    _fetchRoadNames(value); // Live filter
                  },
                ),
              ),
            ),

          // 📄 List of Road Matches
          if (_showSearchBar && _roadNames.isNotEmpty)
            Positioned(
              top: 150,
              left: 10,
              right: 10,
              child: Container(
                height: 300,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ListView.builder(
                  itemCount: _roadNames.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_filteredRoadNames[index]),
                      onTap: () {
                        _highlightSelectedRoad(_filteredRoadNames[index]);
                        setState(() {
                          _showSearchBar = false;
                          _searchController.clear();
                          _filteredRoadNames.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          Positioned(
            top: 180, // adjust as needed
            right: 6,
            child: FloatingActionButton(
              heroTag: "clear_map_fab",
              mini: true,
              backgroundColor: Colors.red.shade700,
              tooltip: "Clear Drawings",
              child: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Clear Map"),
                    content: const Text(
                      "This will remove all drawn roads, boundaries, measurements, and previews.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearAllTemporaryMapDrawings();
                        },
                        child: const Text(
                          "Clear",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Positioned(
            top: 130,
            right: 6,
            child: FloatingActionButton(
              heroTag: "base_map_layers_fab",
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
            bottom: 30,
            left: 10,
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
              bottom: 80, // Moved up to avoid overlaps
              left: 10,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                  maxWidth: 220,
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Legend",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                              fontSize: 14,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _isLegendVisible = false),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          )
                        ],
                      ),
                      Divider(),
                      ..._getDynamicLegendItems(),
                    ],
                  ),
                ),
              ),
            ),
          // 📍 Zoom In/Out Buttons
          Positioned(
            bottom: 20, // Just below the filter toggle
            right: 6,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoom_in_fab",
                  mini: true,
                  backgroundColor: Colors.orange.shade700,
                  onPressed: () async {
                    final controller = await _controller.future;
                    if (!mounted) return;
                    controller.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: Icon(Icons.add, size: 25, color: Colors.white),
                ),
                // SizedBox(height: 5),
                FloatingActionButton(
                  heroTag: "zoom_out_fab",
                  mini: true,
                  backgroundColor: Colors.orange.shade700,
                  onPressed: () async {
                    final controller = await _controller.future;
                    if (!mounted) return;
                    controller.animateCamera(CameraUpdate.zoomOut());
                  },
                  child: Icon(Icons.remove, size: 25, color: Colors.white),
                ),
              ],
            ),
          ),

          Positioned(
            top: 30,
            left: 5,
            right: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🛣️ Info Card with Zone, Ward, Road Count → Now on TOP
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              color: Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Zone: ${_selectedZone ?? 'N/A'}",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.map, color: Colors.orange, size: 20),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Ward: ${_selectedWard ?? 'N/A'}",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.route, color: Colors.orange, size: 20),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Count: $_roadCount",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 170,
            right: 6,
            child: FloatingActionButton(
              heroTag: "map_tools_fab",
              mini: true,
              backgroundColor: Colors.orange.shade700,
              child: const Icon(Icons.tune, color: Colors.white),
              onPressed: _openToolSheet,
            ),
          ),

          Positioned(
            top: 250,
            right: 6,
            child: FloatingActionButton(
              heroTag: "point_data_fab",
              mini: true,
              backgroundColor: Colors.orange.shade700,
              child: const Icon(Icons.location_pin, color: Colors.white),
              onPressed: _showPointDataPopup,
            ),
          ),
          // ElevatedButton.icon(
          //   onPressed: _showPointDataPopup,
          //   icon: const Icon(Icons.location_pin, color: Colors.white),
          //   label: const Text(
          //     "Point Data",
          //     style: TextStyle(color: Colors.white),
          //   ),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.indigo,
          //     minimumSize: const Size(double.infinity, 48),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(10),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  String? _pavementDistressGeometryType;
  List<LatLng> _pavementDistressPolygonPoints = [];
  Polygon? _pavementDistressPolygonPreview;

  List<LatLng> _parkingAreaPolygonPoints = [];
  Polygon? _parkingAreaPolygonPreview;

  Future<void> _showPointDataPopup() async {
    final asset = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Point Asset"),
        children: [
          _assetOption(context, Icons.water_drop, "Manhole"),
          _assetOption(context, Icons.directions_bus, "Bus Stop"),
          _assetOption(context, Icons.local_parking, "Parking Area"),
          _assetOption(context, Icons.signpost, "Road Signage"),
          _assetOption(context, Icons.traffic, "Traffic Safety Features Layer"),
          _assetOption(context, Icons.wc, "Public Toilet"),
          _assetOption(context, Icons.electrical_services, "Transformer"),
          _assetOption(context, Icons.lightbulb_outline, "Street Light"),
          _assetOption(context, Icons.inventory_2_outlined, "Telecom Box"),
          // _assetOption(context, Icons.light, "Street Light"),
        ],
      ),
    );

    if (asset == null) return;
    if (asset == "Traffic Safety Features Layer") {
      final geometryType =
      await _showTrafficSafetyGeometryDialog();

      if (geometryType == null) {
        return;
      }

      _disableAllModes();

      setState(() {
        selectedPointAsset = asset;

        _trafficSafetyGeometryType =
            geometryType;

        _selectedPointLocation = null;

        _trafficSafetyLinePoints.clear();
        _trafficSafetyLinePreview = null;

        _isPointMarking = true;
      });

      if (geometryType == "Point") {
        showSmallHint(
          "Tap on map to mark Traffic Safety point",
        );
      } else {
        showSmallHint(
          "Tap multiple points to draw Traffic Safety line",
        );
      }

      return;
    }

    if (asset == "Parking Area") {
      _disableAllModes();

      setState(() {
        selectedPointAsset = asset;
        _selectedPointLocation = null;
        _parkingAreaPolygonPoints.clear();
        _parkingAreaPolygonPreview = null;
        _isPointMarking = true;
      });

      showSmallHint("Tap multiple points to draw Parking Area polygon");
      return;
    }

    // First stop Road Update / Measure / Reshape etc.
    _disableAllModes();

    setState(() {
      selectedPointAsset = asset;
      _isPointMarking = true;
      _selectedPointLocation = null;
    });

    showSmallHint("Tap on map to mark $asset");
  }



  Future<String?>
  _showTrafficSafetyGeometryDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Select Geometry Type",
          ),
          content: const Text(
            "How do you want to mark this Traffic Safety Feature?",
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  "Point",
                );
              },
              icon: const Icon(
                Icons.location_on,
              ),
              label: const Text(
                "Point",
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  "Line",
                );
              },
              icon: const Icon(
                Icons.timeline,
              ),
              label: const Text(
                "Line",
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _assetOption(BuildContext context, IconData icon, String title) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, title),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
    );
  }

  void _clearAllTemporaryMapDrawings() {
    setState(() {
      // 🔴 Turn OFF all modes
      _isDrawingRoad = false;
      _isSelectingRoad = false;
      _isUpdatingRoad = false;

      // Point Data / Traffic Safety cleanup
      _isPointMarking = false;
      selectedPointAsset = null;
      _selectedPointLocation = null;

      _trafficSafetyGeometryType = null;
      _trafficSafetyLinePoints.clear();
      _trafficSafetyLinePreview = null;

      // 🔴 New road cleanup
      _newRoadPoints.clear();
      _newRoadPreview = null;
      _isExtending = false;
      _extendTapCount = 0;

      _highlightedPolyline = null;

      // 🔴 Selection / highlight cleanup
      _selectedPolylineId = null;
      _searchHighlights.clear();
      _selectedRoadIds.clear();
      _selectedRoadData.clear();

      // 🔴 Missing road cleanup (if active)
      _missingRoadVisible = false;
      _missingRoadPolylines.clear();
    });

    // 🔁 Reload normal roads
    _fetchPolylineDataFromBounds();

    showSmallHint("All temporary drawings cleared");
  }

  final Color _appOrange = Colors.orange.shade700;
  void _selectToolAndClose(VoidCallback action) {
    Navigator.pop(context); // ✅ close sheet FIRST

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action(); // ✅ now safe to call setState
    });
  }

  void _openToolSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(color: _appOrange, width: 1.2),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),

                  // Drag handle
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
                    "Map Tools",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _appOrange,
                    ),
                  ),
                  const SizedBox(height: 6),

                  _activeModeIndicator(),

                  const SizedBox(height: 16),

                  // ---------- EDIT ----------
                  _toolCard(
                    title: "Edit",
                    children: [
                      _toolTile(
                        icon: _isUpdatingRoad ? Icons.close : Icons.edit_road,
                        label: "Update Road",
                        active: _isUpdatingRoad,
                        onTap: () => _selectToolAndClose(_toggleUpdateRoad),
                      ),
                      // _toolTile(
                      //   icon: _isSelectingRoad ? Icons.close : Icons.ads_click,
                      //   label: "Select Road",
                      //   active: _isSelectingRoad,
                      //   onTap: () => _selectToolAndClose(_toggleSelectingRoad),
                      // ),
                    ],
                  ),

                  // ---------- ROAD OPERATIONS ----------
                  _toolCard(
                    title: "Road Operations",
                    children: [
                      _toolTile(
                        icon: Icons.add_road,
                        label: "Create Road",
                        active: _isDrawingRoad,
                        onTap: () => _selectToolAndClose(_startNewRoadCreation),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _activeModeIndicator() {
    String mode = "None";

    if (_isUpdatingRoad)
      mode = "Update Road";
    else if (_isSelectingRoad)
      mode = "Select Road";
    else if (_isDrawingRoad)
      mode = "Create Road";
    else if (_missingRoadVisible)
      mode = "Missing Road";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 14,
            color: mode == "None" ? Colors.grey : _appOrange,
          ),
          const SizedBox(width: 6),
          Text(
            "Active mode: $mode",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: mode == "None" ? Colors.grey : _appOrange,
            ),
          ),
        ],
      ),
    );
  }

  // void _exitReshapeMode() {
  //   _isReshaping = false;
  //   _isReshapeDrawing = false;
  //
  //   // reshape state
  //   _reshapePoints.clear();
  //   _reshapeHistory.clear();
  //   _selectedRoadIdForReshape = null;
  //
  //   // 🔴 VISUAL CLEANUP (THIS WAS MISSING)
  //   _reshapePreview = null;
  //   _highlightedPolyline = null;
  //   _selectedPolylineId = null;
  //
  //   // if you store temporary map overlays
  //   _searchHighlights.clear();
  //
  //   // force map repaint if needed
  //   _fetchPolylineDataFromBounds();
  // }

  void _disableAllModes() {
    setState(() {
      _isSelectingRoad = false;
      _isUpdatingRoad = false;
      _isDrawingRoad = false;
      _isMarkingParking = false;
      _isMarkingToilets = false;
      _isMarkingElectricPoles = false;
      _isMarkingTransformers = false;
      _isPointMarking = false;
      _missingRoadVisible = false;
      
      _highlightedPolyline = null;
      _selectedPolylineId = null;
      _searchHighlights.clear();
      _newRoadConfirmShown = false;
      _newRoadPoints.clear();
      _newRoadPreview = null;
      _isExtending = false;
      _extendTapCount = 0;
      _missingRoadPolylines.clear();
    });

    _exitCreateRoadMode();
  }

  // void _exitCreateRoadMode() {
  //   _isDrawingRoad = false;
  //   _newRoadConfirmShown = false;
  //   _isDrawingRoad = false;
  //
  //   _newRoadPoints.clear();
  //   _newRoadPreview = null;
  //
  //   _isExtending = false;
  //   _extendTapCount = 0;
  //
  //   _highlightedPolyline = null;
  //   _selectedPolylineId = null;
  //
  //   // 🔴 THIS WAS MISSING
  //   newRoadPolylines.clear();
  // }
  void _exitCreateRoadMode() async {
    setState(() {
      _isDrawingRoad = false;
      _newRoadConfirmShown = false;

      _newRoadPoints.clear();
      _newRoadPreview = null;

      _isExtending = false;
      _extendTapCount = 0;

      _highlightedPolyline = null;
      _selectedPolylineId = null;
    });

    // 🔴 rebuild polylines back to normal tap behavior
    await _fetchPolylineDataFromBounds();

    newRoadPolylines.clear();
    await loadNewRoads();
    // loadNewRoads(widget.zoneName ?? '', widget.wardName ?? '');  // Provide default values if null
  }

  void _toggleUpdateRoad() {
    if (_isUpdatingRoad) {
      _disableAllModes();
      showSmallHint("Road Update Mode Disabled");
    } else {
      _disableAllModes(); // 🔴 FORCE all other modes OFF
      setState(() {
        _isUpdatingRoad = true;
      });
      showSmallHint("Road Update Mode Enabled");
    }
  }

  void _toggleSelectingRoad() {
    if (_isSelectingRoad) {
      _disableAllModes();
      showSmallHint("Road Selection Mode Disabled");
    } else {
      _disableAllModes();
      setState(() {
        _isSelectingRoad = true;
      });
      showSmallHint("Road Selection Mode Enabled");
    }
  }

  Widget _toolTile({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: active ? _appOrange.withValues(alpha: 0.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? _appOrange : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ✅ FORCE ICON COLOR (THIS FIXES IT)
            IconTheme(
              data: IconThemeData(
                color: active ? _appOrange : Colors.grey.shade700,
                size: 22,
              ),
              child: Icon(icon),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? _appOrange : Colors.grey.shade800,
                ),
              ),
            ),

            if (active) Icon(Icons.check_circle, size: 18, color: _appOrange),
          ],
        ),
      ),
    );
  }

  Widget _toolCard({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _appOrange, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _appOrange,
                  ),
                ),
              ),
              Divider(color: _appOrange.withValues(alpha: 0.6), thickness: 1),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
      ),
    ),
  );

  Widget _sheetHeader(String title) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );

  void _startNewRoadCreation() async {
    if (_isDrawingRoad) {
      _exitCreateRoadMode();
      showSmallHint("Create Road Mode Disabled");
      return;
    }
    _disableAllModes(); // 🔴 Disable all other modes before starting

    setState(() {
      _newRoadConfirmShown = false;
      _isDrawingRoad = true;

      _newRoadPoints.clear();
      _newRoadPreview = null;
    });

    // 🔴 VERY IMPORTANT: rebuild all polylines so they stop consuming taps
    await _fetchPolylineDataFromBounds();

    // 🔴 rebuild dashed new-road polylines too
    newRoadPolylines.clear();
    await loadNewRoads();
    // loadNewRoads(widget.zoneName ?? '', widget.wardName ?? '');  // Provide default values if null

    showSmallHint("Tap on map to start drawing road");
  }

  LatLng? _lastTappedMapPoint;

  void _showConfirmOrExtendDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Road Creation"),
          content: Text(
            "Do you want to confirm this road or extend it further?",
          ),
          actions: [
            TextButton(
              child: Text("Extend"),
              onPressed: () {
                Navigator.pop(context);
                // _extendRoadDrawing();
                _startExtendMode(); // 👈 NEW FUNCTION
              },
            ),
            TextButton(
              child: Text("Confirm"),
              onPressed: () {
                Navigator.pop(context);
                _openRoadCreationForm();
              },
            ),
          ],
        );
      },
    );
  }


  void _startExtendMode() {
    setState(() {
      _isDrawingRoad = true;
      _isExtending = true;
      _extendTapCount = 0;
      _newRoadConfirmShown = false; // allow dialog again after 3 extend taps
    });
  }

  Future<void> _openRoadCreationForm() async {
    final geometry = _getWKTFromPoints();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewRoadFormScreen(
          geometry: geometry,
          latitude: _currentLat,
          longitude: _currentLng,
          roadAgeCategory:
              widget.roadAgeCategory, // Pass the required parameters
          zoneName: widget.zoneName,
          wardNo: widget.wardNo,
          wardName: widget.wardName,
        ),
      ),
    );

    // 🔥 ALWAYS clear preview when returning
    _exitCreateRoadMode();
  }

  String _getWKTFromPoints() {
    if (_newRoadPoints.isEmpty) return "";

    String coords = _newRoadPoints
        .map((p) => "${p.longitude} ${p.latitude}")
        .join(", ");

    return "LINESTRING ($coords)";
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
                      Divider(color: _appOrange.withValues(alpha: 0.6), thickness: 1),
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

  // void _handleCheckboxChange(String filter, bool value) {
  //   setState(() {
  //     if (value) {
  //       _selectedPriority.add(filter);
  //     } else {
  //       _selectedPriority.remove(filter);
  //     }
  //   });
  //   fetchFilteredRoads(); // Trigger the API call after the checkbox state changes
  // }

  Future<void> fetchFilteredRoads() async {
    debugPrint(
      "--------------------------------------priority Filter ------------------------------------------------------------",
    );

    final queryParams = <String, dynamic>{};

    // 🆕 Get saved Nagar Nigam (schema name)
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('nagarNigam'); // e.g., "kanpur_nn"
    if (nagarNigam != null && nagarNigam.isNotEmpty) {
      queryParams['nagarNigam'] = nagarNigam;
    }

    // Handle roadAgeCategory (make sure it's not empty and format it as needed)
    if (widget.roadAgeCategory.isNotEmpty) {
      List<String> conditions = widget.roadAgeCategory.map((condition) {
        return condition
            .toLowerCase()
            .replaceAll(" ", "_")
            .replaceAll(RegExp(r'[^\w\s]'), ''); // Sanitize input if necessary
      }).toList();

      // Add roadAgeCategory filter as a query parameter
      queryParams['roadAgeCategory'] = conditions;
    }

    // Add selected filters as query parameters
    if (_selectedPriority.contains('School')) {
      queryParams['schoolRoads'] = ['true'];
    }
    if (_selectedPriority.contains('VIP')) {
      queryParams['mainRoads'] = ['true'];
    }
    if (_selectedPriority.contains('Hospital')) {
      queryParams['hospitalRoads'] = ['true'];
    }
    if (_selectedPriority.contains('Bank')) {
      queryParams['bankAtmRoads'] = ['true'];
    }
    if (_selectedPriority.contains('Poor')) {
      queryParams['condition'] = ['Poor'];
    }

    // ✅ 👇 Add this logic right here
    _isPriorityFilterActive = _selectedPriority.any(
      (p) => p == 'School' || p == 'Bank' || p == 'Hospital' || p == 'VIP',
    );

    // ✅ Correctly generate URI with multiple values for same key
    final uri = buildUriWithMultipleValues(
      '${AppConstants.baseURL}api/roads_mobile/filtered_roads?zoneName=${widget.zoneName}&wardNo=${widget.wardNo}&',
      queryParams,
    );

    // Print the final generated API URL
    debugPrint('Final API URL: $uri');

    // Fetch filtered roads from the API
    try {
      final response = await http.get(uri, headers: await _authHeaders());
      if (!mounted) return;

      if (response.statusCode == 200) {
        debugPrint(response.toString());
        final List<dynamic> roads = json.decode(response.body);
        renderRoadsOnMap(roads); // Display filtered roads on the map
      } else {
        debugPrint('Failed to load filtered roads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching filtered roads: $e');
    }
  }

  Future<void> renderRoadsOnMap(List<dynamic> roadsData) async {
    Set<Polyline> polylineSet = {};
    Set<Marker> markerSet = {};
    _polylines.clear(); // 🧹 Clear existing polylines before adding new ones

    for (var item in roadsData) {
      debugPrint('🛣️ Road item: ${jsonEncode(item)}');

      final geoJson = item['geojson'];
      if (geoJson == null) continue;

      // 🔹 parse geometry off UI isolate
      List<LatLng> rawPoints = await compute<dynamic, List<LatLng>>(parseGeoJsonToLatLng, geoJson);
      
      // 🔹 simplify geometry based on zoom
      List<LatLng> points = decimatePoints(rawPoints, _currentZoomLevel);
      
      if (points.isEmpty) continue;

      Color lineColor = Colors.green.shade600;
      String? labelText;

      // ✅ Handle selected priorities
      if (_isPriorityFilterActive) {
        bool matchFound = false;

        if (_selectedPriority.contains('VIP') &&
            (item['category'] == 'Arterial' ||
                item['category'] == 'Sub Arterial')) {
          labelText = 'Main Roads';
          lineColor = Colors.deepPurple.shade800;
          matchFound = true;
        }

        if (_selectedPriority.contains('Bank') &&
            item['bank_atm']?.toString().toLowerCase() == 'yes') {
          labelText = 'Bank/ATM';
          lineColor = Colors.brown.shade600;
          matchFound = true;
        }

        if (_selectedPriority.contains('Hospital') &&
            item['hospital']?.toString().toLowerCase() == 'yes') {
          labelText = 'Hospital';
          lineColor = Colors.teal.shade700;
          matchFound = true;
        }

        if (_selectedPriority.contains('School') &&
            item['educationa']?.toString().toLowerCase() == 'yes') {
          labelText = 'School';
          lineColor = Colors.indigo.shade700;
          matchFound = true;
        }

        if (!matchFound) continue; // skip if no match with selected priority
      } else {
        final condition = item['condition']?.toString() ?? '';
        if (condition == 'Poor') {
          lineColor = Colors.red.shade700;
        } else if (condition == 'Moderate') {
          lineColor = Colors.yellow.shade600;
        }
      }

      final material = item['material']?.toString();

      if (_activeMaterial != null) {
        if (material == null ||
            material.toLowerCase() != _activeMaterial!.toLowerCase()) {
          continue;
        }
        lineColor = materialColors[_activeMaterial!] ?? lineColor;
      }

      if (item['is_confirmed'] == true) {
        lineColor = Colors.blueAccent.shade700;
      }

      final roadId = item['road_id'].toString();
      bool isSelected = _selectedRoadIds.contains(roadId);
      if (isSelected) lineColor = Colors.orange;

      // ROW >= 12 METER
      final double? rowMeter = double.tryParse(
        item['row_meter']?.toString() ?? '',
      );

      if (rowMeter != null && rowMeter >= 12) {
        lineColor = Colors.cyanAccent.shade700;
      }

      if (item['is_updated'] == true) {
        lineColor = Colors.deepPurpleAccent;
      }
      polylineSet.add(
        Polyline(
          polylineId: PolylineId(roadId),
          points: points,
          width: 5,
          color: lineColor,
          // consumeTapEvents: true,
          // consumeTapEvents: !_isDrawingRoad,
          // consumeTapEvents: !(_isDrawingRoad || _isMeasuring),
          consumeTapEvents:
          !(_isDrawingRoad ||
              _isPointMarking),

          onTap: () async {
            final roadId = item['road_id'].toString();
            final isConfirmed = item['is_confirmed'] == true;
            final confirmedAt = item['confirmed_at']?.toString();

            if (_isDrawingRoad)
              return; // 🚫 NEW ROAD MODE → map must receive taps

            if (!_isSelectingRoad && !_isUpdatingRoad ) return;


            // ✏️ If in update mode, open edit form instead of info popup
            if (_isUpdatingRoad) {
              _openRoadUpdateForm(item);
              return;
            }



            // 🟦 Normal selection mode
            if (_isSelectingRoad) {
              setState(() {
                if (_selectedRoadIds.contains(roadId)) {
                  _selectedRoadIds.remove(roadId);
                  _selectedRoadData.removeWhere(
                    (r) => r['road_id'].toString() == roadId,
                  );
                } else {
                  _selectedRoadIds.add(roadId);
                }
              });
              _fetchPolylineDataFromBounds();

            }
          },
        ),
      );

      if (labelText != null && _currentZoomLevel > 14.5) {
        // final labelIcon = await createTextLabelBitmap(labelText);
        final labelIcon = await _getLabelIcon(labelText);

        // 🔄 Recalculate center to avoid label from blocking road
        LatLng center = points[(points.length / 2).floor()];
        LatLng adjustedLabelPosition = LatLng(
          center.latitude + 0.0001, // ⬆ ~11 meters north
          center.longitude + 0.00015, // ➡ ~16 meters east
        );

        markerSet.add(
          Marker(
            markerId: MarkerId("label_$roadId"),
            position: adjustedLabelPosition,
            icon: labelIcon,
            anchor: Offset(0.5, 1),
            zIndex: 999,
          ),
        );
      }
    }

    setState(() {
      _polylines = polylineSet;
      _markers = markerSet;
    });
  }

  final Map<String, BitmapDescriptor> _labelCache = {};
  Future<BitmapDescriptor> _getLabelIcon(String text) async {
    if (_labelCache.containsKey(text)) {
      return _labelCache[text]!;
    }

    final icon = await createTextLabelBitmap(text);
    _labelCache[text] = icon;
    return icon;
  }

  Future<BitmapDescriptor> createTextLabelBitmap(String text) async {
    final double devicePixelRatio = View.of(context).devicePixelRatio;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 28, // ⬅️ Adjusted for density
          fontWeight: FontWeight.bold,
          color: Colors.black,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    // Create a slightly larger canvas for the background box
    final double width = textPainter.width + 8;
    final double height = textPainter.height + 4;

    // Draw background
    final Paint bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);
    
    // Draw text
    textPainter.paint(canvas, const Offset(4, 2));

    final img = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      data!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio, // ⬅️ THIS MAKES IT SMALL & SHARP
    );
  }

  // highlight the road and zooming on the selected road--------------------------------
  // Store the polyline IDs to highlight a selected road
  PolylineId? _selectedPolylineId;

  // This function will be called when a road name is tapped
  void _highlightSelectedRoad(String roadName) {
    // This assumes you already have the road's ID stored with its geometry
    final selectedRoad = _roadNames.firstWhere(
      (road) => road == roadName,
      orElse: () => "",
    );
    if (selectedRoad.isNotEmpty) {
      // Hide list before highlighting
      setState(() {
        _roadNames.clear(); // Hides the list
        _searchController.clear(); // Clears the search bar (optional)
      });

      _highlightRoad(selectedRoad);
    }
  }

  void _highlightRoad(String roadName) async {
    final response = await _fetchRoadDetailsByName(roadName);
    if (!mounted) return;

    if (response == null || response['success'] != true) {
      debugPrint("❌ Road not found");
      return;
    }

    List<dynamic> segments = response['roads'];
    if (segments.isEmpty) return;

    List<Polyline> segmentLines = [];
    List<LatLng> allPoints = [];

    int index = 0;

    for (var seg in segments) {
      if (seg['geojson'] == null) continue;

      List<LatLng> pts = parseGeoJsonToLatLng(seg['geojson']);
      if (pts.isEmpty) continue;

      allPoints.addAll(pts);

      segmentLines.add(
        Polyline(
          polylineId: PolylineId("search-$roadName-$index"),
          points: pts,
          width: 6,
          color: Colors.yellow.shade700,
          // consumeTapEvents: true,
          // consumeTapEvents: !_isDrawingRoad,
          // consumeTapEvents: !(_isDrawingRoad || _isMeasuring),
          consumeTapEvents:
          !(_isDrawingRoad ||
              _isPointMarking),

          // onTap: () {
          //   _showRoadInfoPopup(context, seg);
          // },
        ),
      );

      index++;
    }

    if (segmentLines.isEmpty) return;

    setState(() {
      _searchHighlights.clear(); // clear old search highlights
      _searchHighlights.addAll(segmentLines);
    });

    // Zoom to all points
    if (_controller.isCompleted) {
      final controller = await _controller.future;
      LatLngBounds bounds = _getBoundsFromLatLngList(allPoints);

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  LatLngBounds _getBoundsFromLatLngList(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (var point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  //--------------------------------------- click on road name showing the road and zooming on the road ------------------------------
  // Function to fetch road details by name (coordinates)
  Future<Map<String, dynamic>?> _fetchRoadDetailsByName(String roadName) async {

    final prefs = await SharedPreferences.getInstance();

    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      debugPrint("❌ City/Nagar Nigam not found. Please login again.");
      return null;
    }

    final uri = Uri.parse('${AppConstants.baseURL}api/roads_mobile/roadDetails')
        .replace(
          queryParameters: {
            'roadName': roadName.trim(),
            'nagarNigam': nagarNigam.trim(),
          },
        );

    debugPrint("🔍 ROAD DETAIL URL: $uri");

    debugPrint(
      "---------------------------------------------$uri----------------------------------------------------------------------------------",
    );

    try {
      final response = await http.get(uri, headers: await _authHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data; // Return the road details (coordinates)
      } else {
        debugPrint("Failed to fetch road details");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching road details: $e");
      return null;
    }
  }

  Future<void> _fetchRoadNames(String searchText) async {
    // Map<String, List<String>> queryParams = {};

    final queryParams = <String, dynamic>{};

    // 🆕 Get saved Nagar Nigam (schema name)
    final prefs = await SharedPreferences.getInstance();

    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      debugPrint("❌ City/Nagar Nigam not found. Please login again.");
      return;
    }

    queryParams['nagarNigam'] = nagarNigam.trim();

    final z = widget.zoneName?.trim();

    if (z != null && z.isNotEmpty) {
      queryParams['zoneName'] = [z];
    }

    if (widget.wardNo.isNotEmpty) {
      queryParams['wardNo'] = [widget.wardNo];
    }

    // Add roadAgeCategory (supports multiple)
    if (widget.roadAgeCategory.isNotEmpty) {
      List<String> conditions = widget.roadAgeCategory.map((condition) {
        return condition
            .toLowerCase()
            .replaceAll(" ", "_")
            .replaceAll(RegExp(r'[^\w\s]'), '');
      }).toList();
      queryParams['roadAgeCategory'] = conditions;
    }

    // ✅ Correctly generate URI with multiple values
    final uri = buildUriWithMultipleValues(
      '${AppConstants.baseURL}api/roads_mobile/getRoadNamefilter',
      queryParams,
    );

    debugPrint("🔗 Final request URI: $uri");

    try {
      final response = await http.get(uri, headers: await _authHeaders());
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        List<String> allNames = data
            .map((item) => item['road_name'].toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();

        setState(() {
          _roadNames = allNames;
          _filteredRoadNames = searchText.trim().isEmpty
              ? allNames
              : allNames
                    .where(
                      (name) => name.toLowerCase().contains(
                        searchText.trim().toLowerCase(),
                      ),
                    )
                    .toList();
        });

        debugPrint("🧭 Total unique road names: ${_roadNames.length}");
      } else {
        debugPrint('❌ Failed to load road names: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching road names: $e');
    }
  }

  //------------------------------------------------------ confirm Road Selection  ----------------------------------------------------

  Future<void> _confirmRoadSelection(Map<String, dynamic> roadData) async {
    final roadId = roadData['road_id'];

    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString(
      'nagarNigam',
    ); // e.g. kanpur_nn, lucknow_nn

    final uri = Uri.parse(
      '${AppConstants.baseURL}api/roads_mobile/confirmMobileSelection?roadId=$roadId&nagarNigam=$nagarNigam',
    );

    debugPrint("Confirm URL → $uri");

    try {
      final response = await http.post(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final alreadyConfirmed = result['alreadyConfirmed'] ?? false;
        final confirmedAt = result['confirmedAt'];

        String title = alreadyConfirmed
            ? "Already Confirmed"
            : "Confirmation Successful";
        String message = alreadyConfirmed
            ? "⚠️ This road was already confirmed on:\n$confirmedAt"
            : "✅ Road confirmed successfully at:\n$confirmedAt";

        if (!alreadyConfirmed) {
          // _addRoadToExcel(roadData);
          await ConfirmedRoadDatabase.instance.insertRoad(
            roadData,
          ); // ✅ Save to local DB
        }

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK"),
                ),
              ],
            );
          },
        );
        // ✅ Add to Excel after confirmation is processed and dialog is shown
        // _addRoadToExcel(roadData);
      } else {
        _showErrorDialog("❌ Server error confirming road.");
      }
    } catch (e) {
      debugPrint("❌ Error confirming road: $e");
      _showErrorDialog("❌ Error: Could not confirm road.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // bool isMissingRoadMode = false;



  Future<void> _fetchAndRenderMissingRoads() async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('nagarNigam');

    final queryParams = <String, dynamic>{};

    if (widget.zoneName != null && widget.zoneName!.isNotEmpty) {
      queryParams['zoneName'] = widget.zoneName;
    }

    if (widget.wardNo.isNotEmpty) {
      queryParams['wardNo'] = widget.wardNo;
    }

    final uri = buildUriWithMultipleValues(
      '${AppConstants.baseURL}api/roads_mobile/missing',
      queryParams,
    );

    debugPrint('📡 Missing Roads API → $uri');

    try {
      final response = await http.get(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.isEmpty) {
          _showNoMissingRoadsDialog();
          return;
        }

        await _renderMissingRoadPolylines(data);
      } else {
        debugPrint('❌ Failed to load missing roads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching missing roads: $e');
    }
  }

  void _showNoMissingRoadsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Missing Roads"),
          content: const Text("No missing road available in this ward."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                _disableMissingRoadMode();

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RoadConditionScreen(system: AssetSystem.road),
                  ),
                );
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _disableMissingRoadMode() {
    setState(() {
      _missingRoadVisible = false;
      // isMissingRoadMode = false; // if present
      _missingRoadPolylines.clear();
    });
  }

  Future<void> _renderMissingRoadPolylines(List data) async {
    Set<Polyline> tempPolylines = {};

    int roadIndex = 0;

    for (var item in data) {
      final String? wkt = item['wkt_geom'];
      final bool isUpdated = item['is_updated'] == true;

      if (wkt == null) continue;

      final segments = await compute<String, List<List<LatLng>>>(parseWKTToSegments, wkt);

      int segIndex = 0; // ✅ ADD THIS

      for (final segment in segments) {
        final points = decimatePoints(segment, _currentZoomLevel);
        if (points.length < 2) continue;

        tempPolylines.add(
          Polyline(
            polylineId: PolylineId(
              'missing_road_${roadIndex}_seg_$segIndex', // ✅ UNIQUE
            ),
            points: points,
            color: isUpdated
                ? Colors.lightBlueAccent.shade200
                : Colors.deepOrange.shade400,
            width: 3,
            // consumeTapEvents: true,
            // consumeTapEvents: !_isDrawingRoad,
            // consumeTapEvents: !(_isDrawingRoad || _isMeasuring),
            consumeTapEvents:
            !(_isDrawingRoad ||
                _isPointMarking),

            onTap: () {
              _handleMissingRoadTap(item);
            },
          ),
        );

        segIndex++; // ✅ INCREMENT
      }

      roadIndex++; // one per road
    }

    setState(() {
      _missingRoadPolylines = tempPolylines;
      _missingRoadVisible = true;
    });
  }

  void _handleMissingRoadTap(Map<String, dynamic> missingRoad) {
    final bool alreadyUpdated = missingRoad['is_updated'] == true;

    if (alreadyUpdated) {
      // Show dialog if the road is already updated
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Already Updated"),
          content: const Text(
            "This missing road has already been updated.\n\nDo you want to update it again?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openMissingRoadForm(missingRoad); // Open the form if "Yes"
              },
              child: const Text("Yes, Update Again"),
            ),
          ],
        ),
      );
    } else {
      // Show dialog asking if the road exists or not
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Does This Road Exist?"),
          content: const Text("Is this missing road exist or not?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _markMissingRoadRemark(
                  missingRoad,
                ); // Mark remark and do not open form
              },
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _openMissingRoadForm(missingRoad); // Open form if "Yes"
              },
              child: const Text("Yes, It Exists"),
            ),
          ],
        ),
      );
    }
  } // Function to mark the remark for the missing road (if user clicks "No")

  void _markMissingRoadRemark(Map<String, dynamic> missingRoad) async {
    final String? roadId = missingRoad['road_id']?.toString();

    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('nagarNigam') ?? "";
    final username = prefs.getString('username') ?? "mobile_unknown";

    if (roadId == null || roadId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid road ID')));
      return;
    }

    final payload = {"nagarNigam": nagarNigam, "road_id": roadId};

    final url =
        '${AppConstants.baseURL}api/roads_mobile/saveRemarkForMissingRoad';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json", "X-User": username},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marked as not existing')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed (${response.statusCode})')),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _openMissingRoadForm(Map<String, dynamic> missingRoad) {
    final String? wkt = missingRoad['wkt_geom'];
    if (wkt == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MissingRoadFormScreen(
          geometry: wkt, // 👈 existing geometry
          // isMissingRoad: true,
          existingData: missingRoad, // 👈 prefill
          latitude: _currentLat,
          longitude: _currentLng,
        ),
      ),
    );
  }

  Future<LatLng> _snapToNearestRoad(LatLng tap, {double maxMeters = 30}) async {
    LatLng best = tap;
    double bestDist = maxMeters;

    // ✅ apply endpoint guard ONLY while drawing new road AFTER first point
    final bool preventEndpointSnap =
        _isDrawingRoad && _newRoadPoints.isNotEmpty;

    final all = _polylines.where((p) {
      final id = p.polylineId.value;
      return !id.startsWith("reshape_") &&
          !id.startsWith("measure") &&
          !id.startsWith("missing_") &&
          !id.startsWith("new_road");
    });

    for (final poly in all) {
      final pts = poly.points;

      for (int i = 0; i < pts.length - 1; i++) {
        // 🚫 THIS WAS MISSING
        if (preventEndpointSnap &&
            _isNearEndpoint(tap, pts[i], pts[i + 1], 10)) {
          continue;
        }

        final snap = _closestPointOnSegment(tap, pts[i], pts[i + 1]);

        final d = Geolocator.distanceBetween(
          tap.latitude,
          tap.longitude,
          snap.latitude,
          snap.longitude,
        );

        if (d < bestDist) {
          bestDist = d;
          best = snap;
        }
      }
    }

    return best;
  }

  bool _isNearEndpoint(LatLng p, LatLng a, LatLng b, double meters) {
    final da = Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      a.latitude,
      a.longitude,
    );
    final db = Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      b.latitude,
      b.longitude,
    );
    return da < meters || db < meters;
  }

  Future<Map<String, String>> _authHeaders({bool jsonBody = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    final headers = <String, String>{'Accept': 'application/json'};

    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    debugPrint(
      "AUTH TOKEN EXISTS IN WELCOME: ${token != null && token.trim().isNotEmpty}",
    );

    return headers;
  }

  Future<void> _finishParkingMarking() async {
    if (_pendingRoadData == null || _pendingRoadFormData == null) return;

    final selectedPoints = _parkingPoints.map((point) {
      return {'latitude': point.latitude, 'longitude': point.longitude};
    }).toList();

    final roadData = Map<String, dynamic>.from(_pendingRoadData!);
    final formData = Map<String, dynamic>.from(_pendingRoadFormData!);

    formData['parkingPoints'] = selectedPoints;
    roadData['parkingPoints'] = selectedPoints;

    final ownershipSet = <String>{};
    for (final item in _allRoadsData) {
      final ownership = item['ownership']?.toString();
      if (ownership != null && ownership.trim().isNotEmpty) {
        ownershipSet.add(ownership.trim());
      }
    }
    final ownershipList = ownershipSet.toList()..sort();

    setState(() {
      _isMarkingParking = false;
      _parkingPoints.clear();
    });

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => RoadUpdateScreen(
          roadData: roadData,
          latitude: _currentLat,
          longitude: _currentLng,
          roadAgeCategory: widget.roadAgeCategory,
          zoneName: widget.zoneName,
          wardNo: widget.wardNo,
          wardName: widget.wardName,
          ownershipList: ownershipList,
          initialFormData: formData,
        ),
      ),
    );

    if (result == null) return;



    if (result['action'] == 'mark_transforme') {
      _startTransformerMarking(
        Map<String, dynamic>.from(result['roadData']),
        Map<String, dynamic>.from(result['formData']),
        List<Map<String, dynamic>>.from(result['transformerPoints'] ?? []),
      );
    }
  }

  Future<void> _finishToiletMarking() async {
    if (_pendingRoadData == null || _pendingRoadFormData == null) return;
    final selectedPoints = _toiletPoints.map((point) => {'latitude': point.latitude, 'longitude': point.longitude}).toList();
    final roadData = Map<String, dynamic>.from(_pendingRoadData!);
    final formData = Map<String, dynamic>.from(_pendingRoadFormData!);
    formData['toiletPoints'] = selectedPoints;
    roadData['toiletPoints'] = selectedPoints;
    final ownershipList = _allRoadsData.map((item) => item['ownership']?.toString()).where((o) => o != null && o!.trim().isNotEmpty).cast<String>().toSet().toList()..sort();
    setState(() { _isMarkingToilets = false; _toiletPoints.clear(); });
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (context) => RoadUpdateScreen(roadData: roadData, latitude: _currentLat, longitude: _currentLng, roadAgeCategory: widget.roadAgeCategory, zoneName: widget.zoneName, wardNo: widget.wardNo, wardName: widget.wardName, ownershipList: ownershipList, initialFormData: formData)));
    if (result == null) return;
    if (result['action'] == 'mark_toilet') _startToiletMarking(Map<String, dynamic>.from(result['roadData']), Map<String, dynamic>.from(result['formData']), List<Map<String, dynamic>>.from(result['toiletPoints'] ?? []));
  }


  Future<void> _finishTransformerMarking() async {
    if (_pendingRoadData == null || _pendingRoadFormData == null) return;
    final selectedPoints = _transformerPoints.map((point) => {'latitude': point.latitude, 'longitude': point.longitude}).toList();
    final roadData = Map<String, dynamic>.from(_pendingRoadData!);
    final formData = Map<String, dynamic>.from(_pendingRoadFormData!);
    formData['transformerPoints'] = selectedPoints;
    roadData['transformerPoints'] = selectedPoints;
    final ownershipList = _allRoadsData.map((item) => item['ownership']?.toString()).where((o) => o != null && o!.trim().isNotEmpty).cast<String>().toSet().toList()..sort();
    setState(() { _isMarkingTransformers = false; _transformerPoints.clear(); });
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (context) => RoadUpdateScreen(roadData: roadData, latitude: _currentLat, longitude: _currentLng, roadAgeCategory: widget.roadAgeCategory, zoneName: widget.zoneName, wardNo: widget.wardNo, wardName: widget.wardName, ownershipList: ownershipList, initialFormData: formData)));
    if (result == null) return;
    if (result['action'] == 'mark_transforme') _startTransformerMarking(Map<String, dynamic>.from(result['roadData']), Map<String, dynamic>.from(result['formData']), List<Map<String, dynamic>>.from(result['transformerPoints'] ?? []));
  }

  bool _canConfirmPointAsset() {
    if (!_isPointMarking) {
      return false;
    }

    // Manhole
    if (selectedPointAsset == "Manhole") {
      return _selectedPointLocation != null;
    }

    // Traffic Safety
    if (selectedPointAsset ==
        "Traffic Safety Features Layer") {

      if (_trafficSafetyGeometryType == "Point") {
        return _selectedPointLocation != null;
      }

      if (_trafficSafetyGeometryType == "Line") {
        return _trafficSafetyLinePoints.length >= 2;
      }

      return false;
    }



    // Parking Area
    if (selectedPointAsset == "Parking Area") {
      return _parkingAreaPolygonPoints.length >= 3;
    }

    // Road Signage and other normal point assets
    return _selectedPointLocation != null;
  }


  void _cancelPointMarking() {
    final String assetName =
        selectedPointAsset ?? "Point";

    _clearPointAssetMarking();

    showSmallHint(
      "$assetName marking cancelled",
    );
  }



  Future<void> _confirmPointAsset() async {
    if (selectedPointAsset == null) {
      return;
    }

    final String asset = selectedPointAsset!;

    // ============================================================
    // TRAFFIC SAFETY FEATURES
    // ============================================================
    if (asset == "Traffic Safety Features Layer") {

      // ---------------- POINT ----------------
      if (_trafficSafetyGeometryType == "Point") {
        if (_selectedPointLocation == null) {
          return;
        }

        final LatLng location = _selectedPointLocation!;

        debugPrint("TRAFFIC SAFETY → POINT");
        debugPrint(
          "LOCATION → "
              "${location.latitude}, "
              "${location.longitude}",
        );

        // FORM WILL OPEN HERE

      final bool? saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TrafficSafetyFeaturesFormScreen(
            geometryType: "Point",
            latitude: location.latitude,
            longitude: location.longitude,
            linePoints: const [],
            zoneName: widget.zoneName,
            wardNo: widget.wardNo,
            wardName: widget.wardName,
          ),
        ),
      );


        if (!mounted) return;

        if (saved == true) {
          loadAllPointAssets(); // 👈 REFRESH
        }

        _clearPointAssetMarking();

        return;
      }

      // ---------------- LINE ----------------
      if (_trafficSafetyGeometryType == "Line") {
        if (_trafficSafetyLinePoints.length < 2) {
          return;
        }

        debugPrint("TRAFFIC SAFETY → LINE");

        for (int i = 0;
        i < _trafficSafetyLinePoints.length;
        i++) {
          debugPrint(
            "POINT ${i + 1} → "
                "${_trafficSafetyLinePoints[i].latitude}, "
                "${_trafficSafetyLinePoints[i].longitude}",
          );
        }

        // FORM WILL OPEN HERE

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrafficSafetyFeaturesFormScreen(
            geometryType: "Line",
            latitude: null,
            longitude: null,
            linePoints: List<LatLng>.from(
              _trafficSafetyLinePoints,
            ),
            zoneName: widget.zoneName,
            wardNo: widget.wardNo,
            wardName: widget.wardName,
          ),
        ),
      );


        if (!mounted) return;

        _clearPointAssetMarking();

        return;
      }
    }





    if (asset == "Parking Area") {
      if (_parkingAreaPolygonPoints.length < 3) return;
      await _submitParkingDirectly(_parkingAreaPolygonPoints.toList());
      return;
    }

    // ============================================================
    // NORMAL POINT ASSETS
    // ============================================================

    if (_selectedPointLocation == null) {
      return;
    }

    final LatLng location =
    _selectedPointLocation!;

    // ============================================================
    // ROAD SIGNAGE
    // ============================================================

    if (asset == "Road Signage") {
      final bool? saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RoadSignageFormScreen(
            latitude: location.latitude,
            longitude: location.longitude,
            zoneName: widget.zoneName,
            wardNo: widget.wardNo,
            wardName: widget.wardName,
          ),
        ),
      );

      if (!mounted) return;

      if (saved == true) {
        loadAllPointAssets(); // 👈 REFRESH
      }

      _clearPointAssetMarking();

      return;
    }

    // ============================================================
    // MANHOLE
    // ============================================================

    if (asset == "Manhole") {
      await _submitManholeDirectly(location);
      return;
    }

    if (asset == "Bus Stop") {
      await _submitBusStopDirectly(location);
      return;
    }

    if (asset == "Public Toilet") {
      await _submitToiletDirectly(location);
      return;
    }

    if (asset == "Transformer") {
      await _submitTransformerDirectly(location);
      return;
    }

    if (asset == "Street Light") {
      await _submitStreetLightDirectly(location);
      return;
    }

    if (asset == "Telecom Box") {
      await _submitTelecomBoxDirectly(location);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$asset form is not added yet.",
        ),
      ),
    );
  }

  void _clearPointAssetMarking() {
    if (!mounted) return;

    setState(() {
      _isPointMarking = false;

      selectedPointAsset = null;

      _selectedPointLocation = null;

      _trafficSafetyGeometryType = null;

      _trafficSafetyLinePoints.clear();

      _trafficSafetyLinePreview = null;

      _pavementDistressGeometryType = null;
      _pavementDistressPolygonPoints.clear();
      _pavementDistressPolygonPreview = null;

      _parkingAreaPolygonPoints.clear();
      _parkingAreaPolygonPreview = null;
    });
  }

  Future<void> _submitToiletDirectly(LatLng location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';
      
      // Attempting api/public-toilet/create based on the "Public Toilet" label
      final url = Uri.parse('${AppConstants.baseURL}api/public-toilet/create');
      debugPrint("📡 SUBMITTING PUBLIC TOILET TO: $url");
      
      final request = http.MultipartRequest('POST', url);
      request.headers['X-User'] = username;
      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) request.fields['zoneName'] = widget.zoneName!;
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['createdBy'] = username;
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (!mounted) return;
      Navigator.pop(context);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Public Toilet saved successfully!")));
          if (!mounted) return;
        _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${decoded['error']}")));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission Error: $e")));
      }
    }
  }

  Future<void> _submitStreetLightDirectly(LatLng location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';
      
      final url = Uri.parse('${AppConstants.baseURL}api/street-light/create');
      debugPrint("📡 SUBMITTING STREET LIGHT TO: $url");
      
      final request = http.MultipartRequest('POST', url);
      request.headers['X-User'] = username;
      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) request.fields['zoneName'] = widget.zoneName!;
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['createdBy'] = username;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (!mounted) return;
      Navigator.pop(context);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Street Light saved successfully!")));
          _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${decoded['error']}")));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission Error: $e")));
      }
    }
  }

  Future<void> _submitTelecomBoxDirectly(LatLng location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';
      
      final url = Uri.parse('${AppConstants.baseURL}api/telecom-box/create');
      debugPrint("📡 SUBMITTING TELECOM BOX TO: $url");
      
      final request = http.MultipartRequest('POST', url);
      request.headers['X-User'] = username;
      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) request.fields['zoneName'] = widget.zoneName!;
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['createdBy'] = username;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (!mounted) return;
      Navigator.pop(context);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Telecom Box saved successfully!")));
          _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${decoded['error']}")));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission Error: $e")));
      }
    }
  }

  Future<void> _submitTransformerDirectly(LatLng location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';
      final url = Uri.parse('${AppConstants.baseURL}api/transformer/create');
      final request = http.MultipartRequest('POST', url);
      request.headers['X-User'] = username;
      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) request.fields['zoneName'] = widget.zoneName!;
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['createdBy'] = username;
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;
      Navigator.pop(context);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transformer saved successfully!")));
          _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${decoded['error']}")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission Error: $e")));
      }
    }
  }

  Future<void> _submitParkingDirectly(List<LatLng> points) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';

      final url = Uri.parse('${AppConstants.baseURL}api/parking/create');
      debugPrint("📡 SUBMITTING PARKING AREA TO: $url");

      final request = http.MultipartRequest('POST', url);
      request.headers['X-User'] = username;

      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) {
        request.fields['zoneName'] = widget.zoneName!;
      }
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['geometryType'] = "Polygon";
      request.fields['createdBy'] = username;

      // Encode coordinates
      final coordinates = points.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
      }).toList();
      request.fields['coordinates'] = jsonEncode(coordinates);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Parking Area saved successfully!")),
          );
          _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${decoded['error']}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission Error: $e")),
        );
      }
    }
  }

  Future<void> _submitBusStopDirectly(LatLng location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';

      final url = Uri.parse('${AppConstants.baseURL}api/bus-stop/create');
      debugPrint("📡 SUBMITTING BUS STOP TO: $url");

      final request = http.MultipartRequest('POST', url);

      request.headers['X-User'] = username;

      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) {
        request.fields['zoneName'] = widget.zoneName!;
      }
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['createdBy'] = username;

      debugPrint("📦 PAYLOAD: ${request.fields}");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bus Stop saved successfully!")),
          );
          _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${decoded['error']}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission Error: $e")),
        );
      }
    }
  }

  Future<void> _submitManholeDirectly(LatLng location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';

      final url = Uri.parse('${AppConstants.baseURL}api/manhole/create');
      debugPrint("📡 SUBMITTING MANHOLE TO: $url");

      final request = http.MultipartRequest('POST', url);

      // Headers (No Authorization token as requested)
      request.headers['X-User'] = username;

      // Parameters matching exactly the Java Controller @RequestParam
      request.fields['nagarNigam'] = nagarNigam;
      if (widget.zoneName != null) {
        request.fields['zoneName'] = widget.zoneName!;
      }
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
      request.fields['createdBy'] = username;

      debugPrint("📦 PAYLOAD: ${request.fields}");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Manhole saved successfully!")),
          );
          _clearPointAssetMarking();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${decoded['error']}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save. Status: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission Error: $e")),
        );
      }
    }
  }

  Future<void> loadAllPointAssets() async {
    // final String ward = _selectedWard ?? widget.wardNo;

    final String ward =
    widget.wardNo.trim();

    if (ward.isEmpty) return;


    final String zone =
    (widget.zoneName ?? '').trim();
    try {
      debugPrint("📡 Fetching all point assets for Ward: $ward, Zone: $zone...");
      
      // Pre-generate custom small icons
      final icons = await Future.wait([
        _getSmallCircleIcon(Colors.blue),       // 0: MH
        _getSmallCircleIcon(Colors.deepPurple), // 1: BS
        _getSmallCircleIcon(Colors.amber),      // 2: RS
        _getSmallCircleIcon(Colors.red),        // 3: TS/TR
        _getSmallCircleIcon(Colors.purple),     // 4: TL
        _getSmallCircleIcon(Colors.yellow),     // 5: EP
        _getSmallCircleIcon(Colors.lightBlue),  // 6: SL
        _getSmallCircleIcon(Colors.teal),       // 7: TB
        _getSmallCircleIcon(Colors.orange),     // 8: PD
      ]);
      if (!mounted) return;

      final results = await Future.wait([
        pointAssetService.fetchAssets("Manhole", zone, ward),
        pointAssetService.fetchAssets("Bus Stop", zone, ward),
        pointAssetService.fetchAssets("Parking Area", zone, ward),
        pointAssetService.fetchAssets("Road Signage", zone, ward),
        pointAssetService.fetchAssets("Traffic Safety Features Layer", zone, ward),
        pointAssetService.fetchAssets("Pavement Distress", zone, ward),
        pointAssetService.fetchAssets("Public Toilet", zone, ward),
        pointAssetService.fetchAssets("Electric Pole", zone, ward),
        pointAssetService.fetchAssets("Transformer", zone, ward),
        pointAssetService.fetchAssets("Street Light", zone, ward),
        pointAssetService.fetchAssets("Telecom Box", zone, ward),
      ]);
      if (!mounted) return;

      _processAssetMarkers(results[0], "manhole", icons[0], (m) => _manholeMarkers = m);
      _processAssetMarkers(results[1], "bus_stop", icons[1], (m) => _busStopMarkers = m);
      _processParkingAreas(results[2]);
      _processAssetMarkers(results[3], "road_signage", icons[2], (m) => _roadSignageMarkers = m);
      _processTrafficSafety(results[4], icons[3]);
      _processPavementDistress(results[5], icons[8]);
      _processAssetMarkers(results[6], "toilet", icons[4], (m) => _toiletMarkers = m);
      _processAssetMarkers(results[7], "electric_pole", icons[5], (m) => _electricPoleMarkers = m);
      _processAssetMarkers(results[8], "transformer", icons[3], (m) => _transformerMarkers = m);
      _processAssetMarkers(results[9], "street_light", icons[6], (m) => _streetLightMarkers = m);
      _processAssetMarkers(results[10], "telecom_box", icons[7], (m) => _telecomBoxMarkers = m);

      debugPrint("📊 Assets Count -> MH: ${_manholeMarkers.length}, BS: ${_busStopMarkers.length}, PK: ${_parkingAreaPolygons.length}, RS: ${_roadSignageMarkers.length}, TS: ${_trafficSafetyMarkers.length}, PD: ${_pavementDistressMarkers.length}, TL: ${_toiletMarkers.length}, EP: ${_electricPoleMarkers.length}, TR: ${_transformerMarkers.length}, SL: ${_streetLightMarkers.length}, TB: ${_telecomBoxMarkers.length}");

      if (mounted) setState(() {});
      debugPrint("✅ All point assets loaded");
    } catch (e) {
      debugPrint("❌ Error loading point assets: $e");
    }
  }

  void _processAssetMarkers(List<Map<String, dynamic>> data, String prefix, BitmapDescriptor icon, Function(Set<Marker>) setter) {
    final markers = data.map((item) {
      double? lat;
      double? lng;

      // Case 1: direct latitude/longitude keys
      lat = double.tryParse(item['latitude']?.toString() ?? item['lat']?.toString() ?? '');
      lng = double.tryParse(item['longitude']?.toString() ?? item['lng']?.toString() ?? '');

      // Case 2: GeoJSON Point format
      if ((lat == null || lng == null) && item['type'] == 'Point' && item['coordinates'] is List) {
        final coords = item['coordinates'] as List;
        if (coords.length >= 2) {
          lng = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      }

      if (lat == null || lng == null) return null;

      return Marker(
        markerId: MarkerId("${prefix}_${item['id'] ?? item['gid'] ?? item['road_id'] ?? DateTime.now().millisecondsSinceEpoch}_${data.indexOf(item)}"),
        position: LatLng(lat, lng),
        icon: icon,
        infoWindow: InfoWindow(title: prefix.replaceAll("_", " ").toUpperCase()),
      );
    }).whereType<Marker>().toSet();
    setter(markers);
  }

  double _getHue(Color color) {
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.yellow) return BitmapDescriptor.hueYellow;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.cyan) return BitmapDescriptor.hueCyan;
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    if (color == Colors.purple) return BitmapDescriptor.hueViolet;
    if (color == Colors.deepOrange) return BitmapDescriptor.hueMagenta;
    if (color == Colors.amber) return BitmapDescriptor.hueOrange;
    if (color == Colors.lightBlue) return BitmapDescriptor.hueAzure;
    if (color == Colors.deepPurple) return BitmapDescriptor.hueViolet;
    if (color == Colors.teal) return BitmapDescriptor.hueCyan;
    return BitmapDescriptor.hueRed;
  }

  // Pre-cached small circle icons to keep the map clean
  final Map<int, BitmapDescriptor> _customIconCache = {};

  Future<BitmapDescriptor> _getSmallCircleIcon(Color color) async {
    final int colorVal = color.value;
    if (_customIconCache.containsKey(colorVal)) return _customIconCache[colorVal]!;

    const double size = 12.0; // ⬅️ REDUCED FROM 20.0
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    if (!mounted) return BitmapDescriptor.defaultMarker;
    final double devicePixelRatio = View.of(context).devicePixelRatio;

    final Paint paint = Paint()..color = color;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(size / 2, size / 2), (size / 2) - 1, paint);
    canvas.drawCircle(Offset(size / 2, size / 2), (size / 2) - 1, borderPaint);

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final icon = BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: devicePixelRatio);
    _customIconCache[colorVal] = icon;
    return icon;
  }

  void _processParkingAreas(List<Map<String, dynamic>> data) {
    debugPrint("🚜 Processing ${data.length} parking area records");
    _parkingAreaPolygons = data.map((item) {
      // Look for coordinates in common PostGIS/GeoJSON or custom keys
      final dynamic geoJson = item['geojson'] ?? item['geom'] ?? item;
      
      try {
        Map<String, dynamic> parsedGeo;
        if (geoJson is String) {
          parsedGeo = jsonDecode(geoJson);
        } else if (geoJson is Map) {
          parsedGeo = Map<String, dynamic>.from(geoJson);
        } else {
          return null;
        }

        final String type = parsedGeo['type'] ?? '';
        final dynamic coordinates = parsedGeo['coordinates'];

        if (coordinates == null || coordinates is! List) {
          debugPrint("⚠️ Parking item has no valid coordinates: $parsedGeo");
          return null;
        }

        List<LatLng> points = [];

        if (type == 'Polygon' && coordinates.isNotEmpty) {
          // GeoJSON Polygon: [[[lng, lat], [lng, lat], ...]]
          final List ring = coordinates[0];
          points = ring.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'MultiPolygon' && coordinates.isNotEmpty) {
          // GeoJSON MultiPolygon: [[[[lng, lat], ...]]]
          final List firstPolygon = coordinates[0];
          final List ring = firstPolygon[0];
          points = ring.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        }

        if (points.length < 3) {
          debugPrint("⚠️ Parking polygon has fewer than 3 points: ${points.length}");
          return null;
        }

        debugPrint("✅ Parking polygon parsed with ${points.length} points");

        return Polygon(
          polygonId: PolygonId("parking_persistent_${item['id'] ?? item['gid'] ?? data.indexOf(item)}"),
          points: points,
          fillColor: Colors.blueAccent.withValues(alpha: 0.5),
          strokeColor: Colors.blueAccent,
          strokeWidth: 2,
          zIndex: 10, // Bring to front
        );
      } catch (e) {
        debugPrint("❌ Error parsing parking area: $e");
        return null;
      }
    }).whereType<Polygon>().toSet();
    
    debugPrint("🗺️ Final persistent parking polygons count: ${_parkingAreaPolygons.length}");
  }

  void _processTrafficSafety(List<Map<String, dynamic>> data, BitmapDescriptor icon) {
    final markers = <Marker>{};
    final lines = <Polyline>{};
    for (final item in data) {
      final type = item['geometryType'] ?? item['type'] ?? (item.containsKey('latitude') ? 'Point' : 'Line');
      if (type == "Point") {
        final lat = double.tryParse(item['latitude']?.toString() ?? item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['longitude']?.toString() ?? item['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          markers.add(Marker(
            markerId: MarkerId("ts_${item['id'] ?? item['gid'] ?? item['road_id']}"),
            position: LatLng(lat, lng),
            icon: icon,
            infoWindow: InfoWindow(title: "Traffic Safety Point"),
          ));
        }
      } else if (type == "Line" || type == "LineString") {
        final coordsRaw = item['linePoints'] ?? item['coordinates'] ?? item['geojson'] ?? item['geom'];
        if (coordsRaw != null) {
          try {
            List coords = [];
            if (coordsRaw is String) {
               final decoded = jsonDecode(coordsRaw);
               if (decoded is Map && decoded.containsKey('coordinates')) {
                 coords = decoded['coordinates'];
               } else {
                 coords = decoded;
               }
            } else if (coordsRaw is Map && coordsRaw.containsKey('coordinates')) {
               coords = coordsRaw['coordinates'];
            } else {
               coords = coordsRaw as List;
            }
            
            final List<LatLng> points = coords.map<LatLng>((c) {
               if (c is Map) {
                 final lat = (c['latitude'] ?? c['lat'] ?? 0);
                 final lng = (c['longitude'] ?? c['lng'] ?? 0);
                 return LatLng((lat as num).toDouble(), (lng as num).toDouble());
               }
               if (c is List && c.length >= 2) {
                 return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
               }
               return const LatLng(0, 0);
            }).where((p) => p.latitude != 0).toList();

            if (points.length >= 2) {
              lines.add(Polyline(
                polylineId: PolylineId("ts_line_${item['id'] ?? item['gid'] ?? item['road_id']}"),
                points: points,
                color: Colors.redAccent,
                width: 5,
                zIndex: 6,
              ));
            }
          } catch (e) {
            debugPrint("Error parsing traffic safety line: $e");
          }
        }
      }
    }
    _trafficSafetyMarkers = markers;
    _trafficSafetyLines = lines;
  }

  void _processPavementDistress(List<Map<String, dynamic>> data, BitmapDescriptor icon) {
    final markers = <Marker>{};
    final polygons = <Polygon>{};
    for (final item in data) {
      final type = item['geometryType'] ?? item['type'] ?? (item.containsKey('latitude') ? 'Point' : 'Polygon');
      if (type == "Point") {
        final lat = double.tryParse(item['latitude']?.toString() ?? item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['longitude']?.toString() ?? item['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          markers.add(Marker(
            markerId: MarkerId("pd_${item['id'] ?? item['gid'] ?? item['road_id']}"),
            position: LatLng(lat, lng),
            icon: icon,
            infoWindow: InfoWindow(title: "Pavement Distress Point"),
          ));
        }
      } else if (type == "Polygon" || type == "MultiPolygon") {
        final coordsRaw = item['polygonPoints'] ?? item['coordinates'] ?? item['geojson'] ?? item['geom'] ?? item['polygon_points'];
        if (coordsRaw != null) {
          try {
             List coords = [];
             if (coordsRaw is String) {
               final decoded = jsonDecode(coordsRaw);
               if (decoded is Map && decoded.containsKey('coordinates')) {
                 if (decoded['type'] == 'Polygon') {
                    coords = decoded['coordinates'][0];
                 } else if (decoded['type'] == 'MultiPolygon') {
                    coords = decoded['coordinates'][0][0];
                 } else {
                    coords = decoded['coordinates'];
                 }
               } else {
                 coords = decoded;
               }
             } else if (coordsRaw is Map && coordsRaw.containsKey('coordinates')) {
               if (coordsRaw['type'] == 'Polygon') {
                 coords = coordsRaw['coordinates'][0];
               } else if (coordsRaw['type'] == 'MultiPolygon') {
                 coords = coordsRaw['coordinates'][0][0];
               } else {
                 coords = coordsRaw['coordinates'];
               }
             } else {
               coords = coordsRaw as List;
             }
             
             if (coords.isNotEmpty && coords[0] is List && (coords[0] as List).isNotEmpty && coords[0][0] is List) {
               coords = coords[0];
             }

             final List<LatLng> points = coords.map<LatLng>((c) {
               if (c is Map) {
                 final lat = (c['latitude'] ?? c['lat'] ?? 0);
                 final lng = (c['longitude'] ?? c['lng'] ?? 0);
                 return LatLng((lat as num).toDouble(), (lng as num).toDouble());
               }
               if (c is List && c.length >= 2) {
                 return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
               }
               return const LatLng(0, 0);
             }).where((p) => p.latitude != 0).toList();

            if (points.length >= 3) {
              polygons.add(Polygon(
                polygonId: PolygonId("pd_poly_${item['id'] ?? item['gid'] ?? item['road_id']}"),
                points: points,
                fillColor: Colors.orangeAccent.withValues(alpha: 0.3),
                strokeColor: Colors.orangeAccent,
                strokeWidth: 3,
                zIndex: 4,
              ));
            }
          } catch (e) {
            debugPrint("Error parsing pavement distress polygon: $e");
          }
        }
      }
    }
    _pavementDistressMarkers = markers;
    _pavementDistressPolygons = polygons;
  }
}


List<LatLng> parseGeoJsonToLatLng(dynamic geoJsonInput) {
  final geoJson = geoJsonInput is String ? jsonDecode(geoJsonInput) : geoJsonInput;
  final coordinates = geoJson['coordinates'] as List<dynamic>;

  List<LatLng> points = [];
  for (var coordinate in coordinates) {
    for (var point in coordinate) {
      double lat = (point[1] as num).toDouble();
      double lng = (point[0] as num).toDouble();
      points.add(LatLng(lat, lng));
    }
  }
  return points;
}

List<LatLng> decimatePoints(List<LatLng> pts, double zoom) {
  int step = 1;
  if (zoom < 13) step = 8;
  else if (zoom < 14) step = 4;
  else if (zoom < 15) step = 2;

  if (pts.length <= 2 || step <= 1) return pts;

  final out = <LatLng>[];
  for (int i = 0; i < pts.length; i += step) {
    out.add(pts[i]);
  }
  if (out.last != pts.last) out.add(pts.last);
  return out;
}

List<List<LatLng>> parseWKTToSegments(String wkt) {
  wkt = wkt.trim();

  if (wkt.startsWith('LINESTRING')) {
    String body = wkt.replaceFirst('LINESTRING', '').trim();
    body = body.substring(1, body.length - 1);

    final pts = body.split(',').map((p) {
      final parts = p.trim().split(RegExp(r'\s+'));
      return LatLng(double.parse(parts[1]), double.parse(parts[0]));
    }).toList();

    return pts.length > 1 ? [pts] : [];
  }

  if (wkt.startsWith('MULTILINESTRING')) {
    String body = wkt.replaceFirst('MULTILINESTRING', '').trim();
    body = body.substring(1, body.length - 1);

    final lineStrings = body.split('),(');
    List<List<LatLng>> segments = [];

    for (var line in lineStrings) {
      String clean = line.replaceAll('(', '').replaceAll(')', '');
      final pts = clean.split(',').map((p) {
        final parts = p.trim().split(RegExp(r'\s+'));
        return LatLng(double.parse(parts[1]), double.parse(parts[0]));
      }).toList();

      if (pts.length > 1) segments.add(pts);
    }
    return segments;
  }
  return [];
}
