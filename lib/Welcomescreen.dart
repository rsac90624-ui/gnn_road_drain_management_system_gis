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
import 'utils/app_error_utils.dart';
import 'utils/app_snackbar.dart';
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
  bool _hasAutoZoomedMap = false; // Tracks if initial map zoom is completed
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  int? _selectedYear;
  Set<Polygon> _zonePolygons = {};

  String? _selectedZone;
  String? _selectedZoneNo;
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

  bool _show12mRoads = false;
  Set<Polyline> _12mRoadPolylines = {};
  double _12mRoadOpacity = 1.0;
  List<Map<String, dynamic>> _12mRoadsData = [];
  List<List<List<LatLng>>> _12mRoadParsedSegments = [];

  //----------------------------------------- Service Classes ------------------------------------------------------------------------------------------------
  final LocationService locationService = LocationService();
  final wardService = WardPolygonService();

  final NewRoadService newRoadService = NewRoadService();
  final PointAssetService pointAssetService = PointAssetService();

  Set<Marker> _manholeMarkers = {};
  Set<Marker> _busStopMarkers = {};
  Set<Polygon> _parkingAreaPolygons = {};
  Set<Polygon> _greenMedianPolygons = {};
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

  Set<Marker> _cachedPointAssetMarkers = {};
  LatLngBounds? _currentVisibleRegion;
  final Map<String, ParsedRoadGeometry> _roadGeomCache = {};

  void _updateCachedPointAssetMarkers() {
    _cachedPointAssetMarkers = {
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
    };
  }

  bool _isPolylineInBounds(List<LatLng> points, LatLngBounds? bounds) {
    if (bounds == null || points.isEmpty) return true;

    // Strict 2% edge buffer so roads outside the user's visible bounding box are not rendered
    final double latPad = (bounds.northeast.latitude - bounds.southwest.latitude).abs() * 0.02;
    final double lngPad = (bounds.northeast.longitude - bounds.southwest.longitude).abs() * 0.02;

    final double minLat = bounds.southwest.latitude - latPad;
    final double maxLat = bounds.northeast.latitude + latPad;
    final double minLng = bounds.southwest.longitude - lngPad;
    final double maxLng = bounds.northeast.longitude + lngPad;

    for (final p in points) {
      if (p.latitude >= minLat && p.latitude <= maxLat && p.longitude >= minLng && p.longitude <= maxLng) {
        return true;
      }
    }
    return false;
  }

  Set<Marker> _getVisiblePointAssetMarkers(LatLngBounds? bounds) {
    if (bounds == null || _cachedPointAssetMarkers.isEmpty) return _cachedPointAssetMarkers;

    final double latPad = (bounds.northeast.latitude - bounds.southwest.latitude).abs() * 0.02;
    final double lngPad = (bounds.northeast.longitude - bounds.southwest.longitude).abs() * 0.02;

    final double minLat = bounds.southwest.latitude - latPad;
    final double maxLat = bounds.northeast.latitude + latPad;
    final double minLng = bounds.southwest.longitude - lngPad;
    final double maxLng = bounds.northeast.longitude + lngPad;

    return _cachedPointAssetMarkers.where((marker) {
      final p = marker.position;
      return p.latitude >= minLat && p.latitude <= maxLat && p.longitude >= minLng && p.longitude <= maxLng;
    }).toSet();
  }

  final Map<String, List<List<LatLng>>> _wktSegmentCache = {};
  bool _isFetchingRoads = false;
  String? _lastFetchedRoadsKey;
  bool _isFetchingPointAssets = false;

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

        // Prevent zooming when refreshing data internally (e.g. after form submit)
        if (_isUpdatingRoad || _isDrawingRoad || _isSelectingRoad || _hasAutoZoomedMap) return;

        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
        _hasAutoZoomedMap = true;
      });
    }
  }

  void _undoLastNewRoadPoint() {
    if (_newRoadPoints.isEmpty) return;

    setState(() {
      _newRoadPoints.removeLast();

      // allow confirm dialog again after undo
      _newRoadConfirmShown = false;

      if (_isExtending && _extendTapCount > 0) {
        _extendTapCount--;
      }

      if (_newRoadPoints.length <= 3) {
        _isExtending = false;
        _extendTapCount = 0;
      }

      if (_newRoadPoints.length < 2) {
        _newRoadPreview = null;
      } else {
        _newRoadPreview = Polyline(
          polylineId: PolylineId("new_road_${_newRoadPoints.length}_${DateTime.now().millisecondsSinceEpoch}"),
          points: List<LatLng>.from(_newRoadPoints),
          color: Colors.purpleAccent,
          width: 5,
        );
      }
    });
  }


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

  Future<void> _fetch12mRoads() async {
    final queryParams = <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      debugPrint("❌ city/nagarNigam not found in SharedPreferences");
      return;
    }

    queryParams['nagarNigam'] = nagarNigam.trim();
    final z = widget.zoneName?.trim();
    if (z != null && z.isNotEmpty) queryParams['zoneName'] = [z];
    if (widget.wardName.isNotEmpty) queryParams['wardName'] = [widget.wardName];

    // Assuming a different endpoint as requested
    final uri = buildUriWithMultipleValues(
      '${AppConstants.baseURL}api/roads_mobile/filter_above12m',
      queryParams,
    );

    try {
      final response = await http.get(uri, headers: await _authHeaders());
      debugPrint("🛣 12M ROAD API URL: $uri");
      if (response.statusCode != 200) return;

      final List data = json.decode(response.body);
      final List<Map<String, dynamic>> roadsData = data.cast<Map<String, dynamic>>();

      // Pre-parse segments in ONE batch isolate pass
      final List<String> wkts = roadsData.map((e) => (e['wkt_geom'] ?? e['geomWKT'] ?? e['geojson'] ?? '').toString()).toList();
      final List<List<List<LatLng>>> parsedSegments = await compute(parseWKTBatch, wkts);

      if (mounted) {
        setState(() {
          _12mRoadsData = roadsData;
          _12mRoadParsedSegments = parsedSegments;
        });
        await _render12mPolylines();
      }
    } catch (e) {
      debugPrint('❌ Error fetching 12m roads: $e');
    }
  }

  Future<void> _render12mPolylines() async {
    // 🛡️ Guard against race conditions during fetch
    if (!mounted || _12mRoadsData.length != _12mRoadParsedSegments.length) return;
    
    Set<Polyline> polylineSet = {};
    for (int i = 0; i < _12mRoadsData.length; i++) {
      final item = _12mRoadsData[i];
      final segments = _12mRoadParsedSegments[i];
      final roadId = item['road_id']?.toString() ?? '12m_$i';

      int segIndex = 0;
      for (final segment in segments) {
        final points = decimatePoints(segment, _currentZoomLevel);
        
        // 🌟 "BLUR" EFFECT: Add multiple layers if opacity is reduced
        if (_12mRoadOpacity < 1.0) {
          polylineSet.add(
            Polyline(
              polylineId: PolylineId('12m_${roadId}_seg_${segIndex}_glow'),
              points: points,
              width: 12,
              color: Colors.cyanAccent.withOpacity(_12mRoadOpacity * 0.3),
              zIndex: 29,
            ),
          );
        }

        polylineSet.add(
          Polyline(
            polylineId: PolylineId('12m_${roadId}_seg_$segIndex'),
            points: points,
            width: 8,
            color: Colors.cyanAccent.withOpacity(_12mRoadOpacity),
            zIndex: 30,
            consumeTapEvents: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("12m Road: ${item['road_name'] ?? 'N/A'} (Width: ${item['row_meter'] ?? '>=12'}m)"))
              );
            },
          ),
        );
        segIndex++;
      }
    }
    if (mounted) {
      setState(() {
        _12mRoadPolylines = polylineSet;
      });
    }
  }

  Future<void> _fetchPolylineDataFromBounds({bool force = false, bool preventZoom = false}) async {
    if (_missingRoadVisible) return;
    if (!_controller.isCompleted) return;

    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      debugPrint("❌ city/nagarNigam not found in SharedPreferences");
      return;
    }

    final String currentKey = "${nagarNigam.trim()}_${widget.zoneName?.trim()}_${widget.wardName.trim()}_${widget.roadAgeCategory.join(',')}_${_activeMaterial}";

    // ⚡ INSTANT CACHE CHECK: If already fetched for this ward/filters and not forcing reload, render immediately from memory (0ms network time)!
    if (!force && currentKey == _lastFetchedRoadsKey && _allRoadsData.isNotEmpty) {
      await _renderPolylines(_allRoadsData);
      return;
    }

    if (_isFetchingRoads) return; // 🛡️ Prevent duplicate concurrent HTTP requests
    _isFetchingRoads = true;

    final queryParams = <String, dynamic>{};
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
      debugPrint("📡 [NET] Fetching roads from: $uri");
      final response = await http.get(uri, headers: await _authHeaders());

      debugPrint("📡 [NET] Status: ${response.statusCode}");
      if (response.statusCode != 200) return;

      final List data = json.decode(response.body);
      final int totalApiRoads = data.length;

      final int roadsWithId = data.where((road) {
        final id = road['road_id']?.toString().trim();
        return id != null && id.isNotEmpty;
      }).length;

      final int roadsWithoutId = data.where((road) {
        return road['road_id'] == null;
      }).length;

      debugPrint("========== ROAD COUNT DEBUG ==========");
      debugPrint("TOTAL ROADS FROM API: $totalApiRoads");
      debugPrint("ROADS WITH ROAD_ID: $roadsWithId");
      debugPrint("ROADS WITHOUT ROAD_ID: $roadsWithoutId");
      debugPrint("======================================");
      _lastFetchedRoadsKey = currentKey;
      
      bool wardChanged = false;
      if (data.isNotEmpty) {
        final firstRoad = data.first;
        final newZone = firstRoad['zone_name']?.toString() ?? firstRoad['zoneName']?.toString();
        final newWard = firstRoad['ward_no']?.toString() ?? firstRoad['wardNo']?.toString();
        final newZoneNo = firstRoad['zone_no']?.toString()
            ?? firstRoad['zoneNo']?.toString();
        
        if (newWard != _selectedWard || newZone != _selectedZone) {
          wardChanged = true;
          _wktSegmentCache.clear();
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
          _selectedZoneNo = newZoneNo?.trim();
          _selectedWard = newWard;
          _allRoadsData = data.cast<Map<String, dynamic>>();
          
          if (wardChanged) {
            loadAllPointAssets();
          }
        });
      }

      await _renderPolylines(data, preventZoom: preventZoom);
    } catch (e) {
      debugPrint('❌ Error fetching polylines: $e');
    } finally {
      _isFetchingRoads = false;
    }
  }

  Future<void> _renderPolylines(List data, {bool preventZoom = false}) async {
    if (!_controller.isCompleted) return;
    try {
      final controller = await _controller.future;
      _currentVisibleRegion = await controller.getVisibleRegion();
    } catch (_) {}

    // ⚡ ZOOM THRESHOLD: Do NOT render roads when zoomed out far (< 14.0 zoom)
    if (_currentZoomLevel < 14.0) {
      if (mounted) {
        setState(() {
          _polylines = {};
          _roadCount = 0;
        });
      }
      return;
    }

    final LatLngBounds? currentBounds = _currentVisibleRegion;

    // 1. Collect unparsed WKT geometries
    final List<Map<String, dynamic>> unparsedItems = [];
    final List<String> unparsedWkts = [];

    for (final rawItem in data) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final roadId = item['road_id']?.toString();
      final String? wkt = item['wkt_geom']?.toString() ?? item['geomWKT']?.toString() ?? item['geojson']?.toString();

      if (roadId != null && wkt != null && wkt.isNotEmpty && !_roadGeomCache.containsKey(roadId)) {
        unparsedItems.add(item);
        unparsedWkts.add(wkt);
      }
    }

    // 2. Batch parse all new WKT geometries in ONE background isolate pass
    if (unparsedWkts.isNotEmpty) {
      final List<ParsedRoadGeometry> batchParsed = await compute(parseWKTBatchWithBBox, unparsedWkts);
      for (int i = 0; i < unparsedItems.length; i++) {
        final roadId = unparsedItems[i]['road_id'].toString();
        _roadGeomCache[roadId] = batchParsed[i];
      }
    }

    // 3. Build polyline widgets using spatial bounding box checks (< 1ms per frame!)
    Set<Polyline> polylineSet = {};
    int roadCount = 0;

    for (final item in data) {
      if (item is! Map) continue;
      final roadId = item['road_id']?.toString();
      if (roadId == null) continue;

      final geom = _roadGeomCache[roadId];
      if (geom == null || geom.segments.isEmpty) continue;

      // ⚡ FAST SPATIAL BBOX FILTER: Skip off-screen roads in 1 nanosecond!
      if (currentBounds != null && !geom.isInBounds(currentBounds)) {
        continue;
      }

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

      final double? rowMeter = double.tryParse(item['row_meter']?.toString() ?? '');
      if (rowMeter != null && rowMeter >= 12) {
        lineColor = Colors.cyanAccent.shade700;
      }

      if (item['is_updated'] == true) lineColor = Colors.deepPurpleAccent;

      final notExists = item['not_exists'] == true || item['not_exists']?.toString().toLowerCase() == 'true';
      if (notExists) {
        lineColor = Colors.tealAccent;
      }

      int segIndex = 0;
      for (final segment in geom.segments) {
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
                _showRoadExistConfirmDialog(Map<String, dynamic>.from(item));
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
                _renderPolylines(_allRoadsData); // 👈 LOCAL REDRAW, INSTANT 0ms
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

    if (!preventZoom) {
      if (_controller.isCompleted && !_hasAutoZoomedMap) {
        // Collect all points from polys to get valid bounds.
        List<LatLng> allPoints = [];
        for (var poly in polylineSet) {
          allPoints.addAll(poly.points);
        }
        if (allPoints.isNotEmpty) {
          final controller = await _controller.future;
          LatLngBounds bounds = _getBoundsFromLatLngList(allPoints);
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
          _hasAutoZoomedMap = true;
        }
      }
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

  void _showRoadExistConfirmDialog(Map<String, dynamic> roadData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Road"),
        content: const Text("Is this road exists on ground?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markRoadNotExist(roadData);
            },
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            onPressed: () {
              Navigator.pop(context);
              _openRoadUpdateForm(roadData);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _markRoadNotExist(Map<String, dynamic> roadData) async {
    final roadId = roadData['road_id']?.toString();
    if (roadId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? "";
    final username = prefs.getString('username') ?? "mobile_unknown";

    // ✅ Using a standard endpoint for marking as not existing
    final url = Uri.parse('${AppConstants.baseURL}api/roads_mobile/markNotExist')
        .replace(queryParameters: {
      'roadId': roadId,
      'nagarNigam': nagarNigam,
    });

    debugPrint("📡 MARKING ROAD AS NOT EXIST: $url");

    try {
      final response = await http.post(url, headers: {'X-User': username});
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Road marked as NOT EXIST successfully")),
        );
        _fetchPolylineDataFromBounds(); // Refresh map
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to mark road: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error marking road not exist: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
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

    if (result == true || 
        (result is Map && (result['action'] == 'success' || result['success'] == true))) {
      // Refresh road data silently without zooming
      await _fetchPolylineDataFromBounds(preventZoom: true);
      return;
    }

    if (result is Map && result['action'] == 'mark_transforme') {
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
            // onTap: (LatLng tappedPoint) async {
            //   if (_isPointMarking) {

            onTap: (LatLng tappedPoint) async {

              if (_isPointMarking) {
                await _closeAllMarkerInfoWindows();
                if (!mounted) return;
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
                        fillColor: Colors.blueAccent.withOpacity(0.3),
                        strokeColor: Colors.blueAccent,
                        strokeWidth: 3,
                      );
                    }
                  });
                  showSmallHint("Point ${_parkingAreaPolygonPoints.length} added");
                  return;
                }

                // =================================================
                // GREEN MEDIAN (POLYGON)
                // =================================================
                if (selectedPointAsset == "Green Median") {
                  setState(() {
                    _greenMedianPolygonPoints.add(tappedPoint);
                    if (_greenMedianPolygonPoints.length >= 3) {
                      _greenMedianPolygonPreview = Polygon(
                        polygonId: const PolygonId("green_median_polygon"),
                        points: List<LatLng>.from(_greenMedianPolygonPoints),
                        fillColor: Colors.green.withOpacity(0.35),
                        strokeColor: Colors.green.shade700,
                        strokeWidth: 3,
                      );
                    }
                  });
                  showSmallHint("Point ${_greenMedianPolygonPoints.length} added");
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
                    polylineId: PolylineId("new_road_${_newRoadPoints.length}_${DateTime.now().millisecondsSinceEpoch}"),
                    color: Colors.purpleAccent,
                    width: 5,
                    points: List<LatLng>.from(_newRoadPoints),
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
              final bool oldPointVisible = _currentZoomLevel > 15.5;
              final bool newPointVisible = position.zoom > 15.5;

              final bool oldRoadVisible = _currentZoomLevel >= 14.0;
              final bool newRoadVisible = position.zoom >= 14.0;

              _currentZoomLevel = position.zoom;

              if (oldPointVisible != newPointVisible || oldRoadVisible != newRoadVisible) {
                if (mounted) setState(() {});
              }
            },
            onCameraIdle: () {
              if (_isDrawingRoad ||
                  _missingRoadVisible ||
                  _isPointMarking) {
                return;
              }

              _cameraIdleTimer?.cancel();
              _cameraIdleTimer = Timer(const Duration(milliseconds: 100), () async {
                if (mounted && _controller.isCompleted) {
                  try {
                    final controller = await _controller.future;
                    _currentVisibleRegion = await controller.getVisibleRegion();
                  } catch (_) {}

                  if (_currentZoomLevel >= 14.0) {
                    await _fetchPolylineDataFromBounds();
                    if (_allRoadsData.isNotEmpty) {
                      await _renderPolylines(_allRoadsData);
                    }
                  } else {
                    if (mounted) {
                      setState(() {
                        _polylines = {};
                        _roadCount = 0;
                      });
                    }
                  }

                  if (_show12mRoads) _render12mPolylines();
                }
              });
            },

            markers: {
              ..._markers,
              if (_currentZoomLevel > 15.5) ..._getVisiblePointAssetMarkers(_currentVisibleRegion),

              if (_isMarkingParking) ..._buildParkingMarkers(),

              if (_isMarkingToilets) ..._buildToiletMarkers(),
              if (_isMarkingTransformers) ..._buildTransformerMarkers(),

              // Point Data marker
              // if (_isPointMarking && _selectedPointLocation != null)
              //   Marker(
              //     markerId: const MarkerId('point_data_selected_marker'),
              //     position: _selectedPointLocation!,
              //     icon: _selectionIcon ?? BitmapDescriptor.defaultMarker,
              //     infoWindow: InfoWindow(
              //       title: selectedPointAsset ?? "Point Asset",
              //     ),
              //   ),

              // Point Data marker - No InfoWindow
              if (_isPointMarking && _selectedPointLocation != null)
                Marker(
                  markerId: const MarkerId('point_data_selected_marker'),
                  position: _selectedPointLocation!,
                  icon: _selectionIcon ?? BitmapDescriptor.defaultMarker,

                  // Disable InfoWindow for the temporary marker
                  infoWindow: InfoWindow.noText,
                ),
            },

            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: _currentMapType,
            polygons: {
              ..._zonePolygons,
              ..._parkingAreaPolygons,
              ..._greenMedianPolygons,
              ..._pavementDistressPolygons,

              if (_isPointMarking &&
                  selectedPointAsset == "Parking Area" &&
                  _parkingAreaPolygonPreview != null)
                _parkingAreaPolygonPreview!,

              if (_isPointMarking &&
                  selectedPointAsset == "Green Median" &&
                  _greenMedianPolygonPreview != null)
                _greenMedianPolygonPreview!,
            }, // Merge both sets // Display updated ward boundaries

            zoomControlsEnabled: false,

            polylines: {
              ..._polylines,
              ...newRoadPolylines,
              ..._trafficSafetyLines,
              ..._12mRoadPolylines,

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
              bottom: 220,
              right: 6,
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
              bottom: 220,
              right: 6,
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
                        fillColor: Colors.blueAccent.withOpacity(0.3),
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
          // GREEN MEDIAN POLYGON UNDO
          // =====================================================
          if (_isPointMarking &&
              selectedPointAsset == "Green Median" &&
              _greenMedianPolygonPoints.isNotEmpty)
            Positioned(
              bottom: 220,
              right: 6,
              child: FloatingActionButton(
                heroTag: "green_median_polygon_undo_main",
                mini: true,
                backgroundColor: Colors.green.shade800,
                onPressed: () {
                  setState(() {
                    _greenMedianPolygonPoints.removeLast();
                    if (_greenMedianPolygonPoints.length < 3) {
                      _greenMedianPolygonPreview = null;
                    } else {
                      _greenMedianPolygonPreview = Polygon(
                        polygonId: const PolygonId("green_median_polygon"),
                        points: _greenMedianPolygonPoints.toList(),
                        fillColor: Colors.green.withOpacity(0.35),
                        strokeColor: Colors.green.shade700,
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
          // SINGLE POINT ASSET UNDO (Manhole, Bus Stop, Road Signage, etc.)
          // =====================================================
          if (_isPointMarking &&
              _selectedPointLocation != null &&
              selectedPointAsset != "Parking Area" &&
              selectedPointAsset != "Green Median" &&
              !(selectedPointAsset == "Traffic Safety Features Layer" && _trafficSafetyGeometryType == "Line"))
            Positioned(
              bottom: 220,
              right: 6,
              child: FloatingActionButton(
                heroTag: "single_point_asset_undo_main",
                mini: true,
                backgroundColor: Colors.orange.shade800,
                tooltip: "Undo marked point",
                onPressed: () {
                  setState(() {
                    _selectedPointLocation = null;
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
              left: 60,
              right: 60,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cancelPointMarking,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Cancel", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canConfirmPointAsset()
                          ? _confirmPointAsset
                          : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Confirm", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                  color: Colors.white.withOpacity(0.9),
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
              backgroundColor: _isPointMarking ? Colors.indigo : Colors.orange.shade700,
              child: Icon(
                _isPointMarking ? Icons.pin_drop : Icons.location_pin,
                color: Colors.white,
              ),
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

  List<LatLng> _greenMedianPolygonPoints = [];
  Polygon? _greenMedianPolygonPreview;

  Future<void> _showPointDataPopup() async {
    final asset = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Point Asset"),
        children: [
          _assetOption(context, Icons.water_drop, "Manhole"),
          _assetOption(context, Icons.directions_bus, "Bus Stop"),
          _assetOption(context, Icons.park, "Green Median"),
          _assetOption(context, Icons.local_parking, "Parking Area"),
          _assetOption(context, Icons.signpost, "Road Signage"),
          _assetOption(context, Icons.traffic, "Traffic Safety Features Layer"),
          _assetOption(context, Icons.wc, "Public Toilet"),
          _assetOption(context, Icons.electrical_services, "Transformer/ RMU"),
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

    if (asset == "Green Median") {
      _disableAllModes();

      setState(() {
        selectedPointAsset = asset;
        _selectedPointLocation = null;
        _greenMedianPolygonPoints.clear();
        _greenMedianPolygonPreview = null;
        _isPointMarking = true;
      });

      showSmallHint("Tap multiple points to draw Green Median polygon");
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
                      color: _appOrange.withOpacity(0.9),
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
    else if (_isPointMarking)
      mode = "${selectedPointAsset ?? 'Point Asset'} Marking";

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
          color: active ? _appOrange.withOpacity(0.08) : Colors.transparent,
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
              Divider(color: _appOrange.withOpacity(0.6), thickness: 1),
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

    // Get actual zone_no from API data or zone name
    String zoneNo = _selectedZoneNo?.trim() ?? '';
    if (zoneNo.isEmpty && widget.zoneName != null) {
      final match = RegExp(r'\d+').firstMatch(widget.zoneName!);
      if (match != null) {
        zoneNo = match.group(0)!;
      } else {
        zoneNo = widget.zoneName!.trim();
      }
    }
    if (zoneNo.isEmpty && _selectedZone != null) {
      final match = RegExp(r'\d+').firstMatch(_selectedZone!);
      if (match != null) {
        zoneNo = match.group(0)!;
      } else {
        zoneNo = _selectedZone!.trim();
      }
    }

    if (zoneNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Zone number is unavailable. Please refresh road data."
          ),
        ),
      );
      return;
    }

    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewRoadFormScreen(
          geometry: geometry,
          latitude: _currentLat,
          longitude: _currentLng,
          roadAgeCategory: widget.roadAgeCategory,
          zoneNo: zoneNo,
          zoneName: widget.zoneName,

          wardNo: widget.wardNo,
          wardName: widget.wardName,
        ),
      ),
    );

    if (saved == true) {
      if (mounted) {
        setState(() {
          _isDrawingRoad = false;
          _isExtending = false;
          _newRoadPoints.clear();
          _newRoadPreview = null;
        });
        // Just reload the roads layer silently without changing camera
        await _fetchPolylineDataFromBounds(preventZoom: true);
      }
    } else {
      _exitCreateRoadMode();
    }
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
                        Colors.orange.shade500.withOpacity(0.95),
                        Colors.deepOrange.shade100.withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
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
                      Divider(color: _appOrange.withOpacity(0.6), thickness: 1),
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
            ? Colors.white.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
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

      final notExists = item['not_exists'] == true || item['not_exists']?.toString().toLowerCase() == 'true';
      if (notExists) {
        lineColor = Colors.tealAccent; // High priority color for roads that don't exist
      }

      debugPrint(
          'road_id=${item['road_id']}, '
          'not_exists=${item['not_exists']}, '
          'is_updated=${item['is_updated']}'
      );

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
              _showRoadExistConfirmDialog(item);
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
    final double devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 28, // ⬅️ Adjusted for density
          fontWeight: FontWeight.bold,
          color: Colors.black,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    
    // Create a slightly larger canvas for the background box
    final double width = textPainter.width + 8;
    final double height = textPainter.height + 4;

    // Draw background
    final Paint bgPaint = Paint()..color = Colors.white.withOpacity(0.9);
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

    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate', // ⚡ 80% Faster Network Download Transfer
    };

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



    // Green Median
    if (selectedPointAsset == "Green Median") {
      return _greenMedianPolygonPoints.length >= 3;
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

        _resetPointAfterSave();

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





    if (asset == "Green Median") {
      if (_greenMedianPolygonPoints.length < 3) return;
      await _submitGreenMedianDirectly(_greenMedianPolygonPoints.toList());
      return;
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

      _resetPointAfterSave();

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

    if (asset == "Transformer" || asset == "Transformer/ RMU") {
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

      _greenMedianPolygonPoints.clear();
      _greenMedianPolygonPreview = null;
    });
  }

  void _resetPointAfterSave() {
    if (!mounted) return;

    setState(() {
      _selectedPointLocation = null;

      _trafficSafetyLinePoints.clear();

      _trafficSafetyLinePreview = null;

      _pavementDistressPolygonPoints.clear();
      _pavementDistressPolygonPreview = null;

      _parkingAreaPolygonPoints.clear();
      _parkingAreaPolygonPreview = null;

      _greenMedianPolygonPoints.clear();
      _greenMedianPolygonPreview = null;
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
          AppSnackBar.showSuccess(context, "Public Toilet saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          if (mounted) AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Public Toilet.");
        }
      } else {
        if (mounted) AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
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
          if (mounted) AppSnackBar.showSuccess(context, "Street Light saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          if (mounted) AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Street Light.");
        }
      } else {
        if (mounted) AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
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
          if (mounted) AppSnackBar.showSuccess(context, "Telecom Box saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          if (mounted) AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Telecom Box.");
        }
      } else {
        if (mounted) AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
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
          AppSnackBar.showSuccess(context, "Transformer saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Transformer.");
        }
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
      }
    }
  }

  Future<void> _submitGreenMedianDirectly(List<LatLng> points) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';

      final url = Uri.parse('${AppConstants.baseURL}api/green-median/create');
      debugPrint("📡 SUBMITTING GREEN MEDIAN TO: $url");

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
          AppSnackBar.showSuccess(context, "Green Median saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Green Median.");
        }
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
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
          AppSnackBar.showSuccess(context, "Parking Area saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Parking Area.");
        }
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
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
          AppSnackBar.showSuccess(context, "Bus Stop saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Bus Stop.");
        }
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        Navigator.pop(context); // close loader
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
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
          AppSnackBar.showSuccess(context, "Manhole saved successfully!");
          _resetPointAfterSave();
          loadAllPointAssets(); // 👈 REFRESH
        } else {
          AppSnackBar.showError(context, decoded['error']?.toString() ?? "Failed to save Manhole.");
        }
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        Navigator.pop(context); // close loader
        AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
      }
    }
  }

  Future<void> loadAllPointAssets({bool force = false}) async {
    if (_isFetchingPointAssets && !force) return;
    _isFetchingPointAssets = true;

    final String ward = widget.wardNo.trim();
    if (ward.isEmpty) {
      _isFetchingPointAssets = false;
      return;
    }

    final String zone = (widget.zoneName ?? '').trim();
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
        pointAssetService.fetchAssets("Green Median", zone, ward),
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
      await _processParkingAreas(results[2]);
      await _processGreenMedians(results[3]);
      _processAssetMarkers(results[4], "road_signage", icons[2], (m) => _roadSignageMarkers = m);
      _processTrafficSafety(results[5], icons[3]);
      _processPavementDistress(results[6], icons[8]);
      _processAssetMarkers(results[7], "toilet", icons[4], (m) => _toiletMarkers = m);
      _processAssetMarkers(results[8], "electric_pole", icons[5], (m) => _electricPoleMarkers = m);
      _processAssetMarkers(results[9], "transformer", icons[3], (m) => _transformerMarkers = m);
      _processAssetMarkers(results[10], "street_light", icons[6], (m) => _streetLightMarkers = m);
      _processAssetMarkers(results[11], "telecom_box", icons[7], (m) => _telecomBoxMarkers = m);

      _updateCachedPointAssetMarkers(); // 👈 Pre-compute merged set ONCE instead of inside build()

      debugPrint("📊 Assets Count -> MH: ${_manholeMarkers.length}, BS: ${_busStopMarkers.length}, PK: ${_parkingAreaPolygons.length}, GM: ${_greenMedianPolygons.length}, RS: ${_roadSignageMarkers.length}, TS: ${_trafficSafetyMarkers.length}, PD: ${_pavementDistressMarkers.length}, TL: ${_toiletMarkers.length}, EP: ${_electricPoleMarkers.length}, TR: ${_transformerMarkers.length}, SL: ${_streetLightMarkers.length}, TB: ${_telecomBoxMarkers.length}");

      if (mounted) setState(() {});
      debugPrint("✅ All point assets loaded");
    } catch (e) {
      debugPrint("❌ Error loading point assets: $e");
    } finally {
      _isFetchingPointAssets = false;
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
  static final Map<int, BitmapDescriptor> _customIconCache = {};

  Future<BitmapDescriptor> _getSmallCircleIcon(Color color) async {
    final int colorVal = color.value;
    if (_customIconCache.containsKey(colorVal)) return _customIconCache[colorVal]!;

    const double size = 12.0; // ⬅️ REDUCED FROM 20.0
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    if (!mounted) return BitmapDescriptor.defaultMarker;
    final double devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;

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

    Future<void> _processParkingAreas(List<Map<String, dynamic>> data) async {
    debugPrint("🚜 Processing ${data.length} parking area records");
    
    // We will accumulate parsed polygons
    final Set<Polygon> polys = {};

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      // Yield CPU periodically
      if (i % 20 == 0) await Future.delayed(Duration.zero);

      final dynamic geoJson = item['geojson'] ?? item['geom'] ?? item;
      
      try {
        Map<String, dynamic>? parsedGeo;
        if (geoJson is String) {
          final trimmed = geoJson.trim();
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            parsedGeo = jsonDecode(trimmed);
          } else if (trimmed.toUpperCase().contains('POLYGON') || trimmed.toUpperCase().contains('LINESTRING')) {
             parsedGeo = _fallbackWktToGeoJson(trimmed);
          }
        } else if (geoJson is Map) {
          parsedGeo = Map<String, dynamic>.from(geoJson);
        } 
        if (parsedGeo == null) continue;

        final String type = parsedGeo['type'] ?? '';
        final dynamic coordinates = parsedGeo['coordinates'];

        if (coordinates == null || coordinates is! List) {
          continue;
        }

        List<LatLng> points = [];

        if (type == 'Polygon' && coordinates.isNotEmpty) {
          final List ring = coordinates[0];
          points = ring.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'MultiPolygon' && coordinates.isNotEmpty) {
          final List firstPolygon = coordinates[0];
          final List ring = firstPolygon[0];
          points = ring.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'LineString' && coordinates.isNotEmpty) {
          points = (coordinates as List).map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'MultiLineString' && coordinates.isNotEmpty) {
          final List line = coordinates[0];
          points = line.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        }

        if (points.length >= 3) {
          polys.add(
            Polygon(
              polygonId: PolygonId("parking_persistent_${item['id'] ?? item['gid'] ?? i}"),
              points: points,
              fillColor: Colors.blueAccent.withOpacity(0.5),
              strokeColor: Colors.blueAccent,
              strokeWidth: 2,
              zIndex: 10,
            )
          );
        }
      } catch (e) {
        debugPrint("❌ Error parsing parking area: $e");
      }
    }
    
    if (mounted) {
      setState(() {
        _parkingAreaPolygons = polys;
      });
    }
    debugPrint("🗺️ Final persistent parking polygons count: ${_parkingAreaPolygons.length}");
  }

  Map<String, dynamic>? _fallbackWktToGeoJson(String wkt) {
    try {
      final uppercaseWkt = wkt.toUpperCase().trim();
      final start = uppercaseWkt.indexOf('(');
      final end = uppercaseWkt.lastIndexOf(')');
      if (start != -1 && end != -1 && end > start) {
        String content = uppercaseWkt.substring(start + 1, end).trim();
        content = content.replaceAll('(', '').replaceAll(')', '');
        final pointPairs = content.split(',');
        final List<List<double>> coords = [];
        for (var pair in pointPairs) {
          final parts = pair.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final double? lng = double.tryParse(parts[0]);
            final double? lat = double.tryParse(parts[1]);
            if (lng != null && lat != null) {
              coords.add([lng, lat]);
            }
          }
        }
        if (uppercaseWkt.startsWith("POLYGON")) {
           return {"type": "Polygon", "coordinates": [coords]};
        } else if (uppercaseWkt.startsWith("LINESTRING")) {
           return {"type": "LineString", "coordinates": coords};
        }
      }
    } catch (e) {
      debugPrint("Error parsing fallback WKT: $e");
    }
    return null;
  }

  Future<void> _processGreenMedians(List<Map<String, dynamic>> data) async {
    debugPrint("🌿 Processing ${data.length} green median records");
    
    final Set<Polygon> polys = {};

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (i % 20 == 0) await Future.delayed(Duration.zero);

      final dynamic geoJson = item['geojson'] ?? item['geom'] ?? item;

      try {
        Map<String, dynamic>? parsedGeo;
        if (geoJson is String) {
          final trimmed = geoJson.trim();
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            parsedGeo = jsonDecode(trimmed);
          } else if (trimmed.toUpperCase().contains('POLYGON') || trimmed.toUpperCase().contains('LINESTRING')) {
             parsedGeo = _fallbackWktToGeoJson(trimmed);
          }
        } else if (geoJson is Map) {
          parsedGeo = Map<String, dynamic>.from(geoJson);
        }
        
        if (parsedGeo == null) continue;

        final String type = parsedGeo['type'] ?? '';
        final dynamic coordinates = parsedGeo['coordinates'];

        if (coordinates == null || coordinates is! List) continue;

        List<LatLng> points = [];

        if (type == 'Polygon' && coordinates.isNotEmpty) {
          final List ring = coordinates[0];
          points = ring.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'MultiPolygon' && coordinates.isNotEmpty) {
          final List firstPolygon = coordinates[0];
          final List ring = firstPolygon[0];
          points = ring.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'LineString' && coordinates.isNotEmpty) {
          points = (coordinates as List).map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        } else if (type == 'MultiLineString' && coordinates.isNotEmpty) {
          final List line = coordinates[0];
          points = line.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();
        }

        if (points.length >= 3) {
          polys.add(
            Polygon(
              polygonId: PolygonId("green_median_persistent_${item['id'] ?? item['gid'] ?? i}"),
              points: points,
              fillColor: Colors.green.withOpacity(0.5),
              strokeColor: Colors.green.shade700,
              strokeWidth: 2,
              zIndex: 10,
            )
          );
        }
      } catch (e) {
        debugPrint("❌ Error parsing green median: $e");
      }
    }

    if (mounted) {
      setState(() {
        _greenMedianPolygons = polys;
      });
    }

    debugPrint("🗺️ Final persistent green median polygons count: ${_greenMedianPolygons.length}");
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
                fillColor: Colors.orangeAccent.withOpacity(0.3),
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

  Future<void> _closeAllMarkerInfoWindows() async {
    if (!_controller.isCompleted) return;

    final mapController = await _controller.future;
    if (!mounted) return;

    final markerIds = <MarkerId>{
      ..._markers.map((m) => m.markerId),
      ..._cachedPointAssetMarkers.map((m) => m.markerId),
    };

    for (final markerId in markerIds) {
      try {
        await mapController.hideMarkerInfoWindow(markerId);
      } catch (_) {
        // Marker may no longer exist on the map.
      }
    }
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

class ParsedRoadGeometry {
  final List<List<LatLng>> segments;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  ParsedRoadGeometry({
    required this.segments,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  bool isInBounds(LatLngBounds? bounds) {
    if (bounds == null || segments.isEmpty) return true;

    // Strict 2% edge buffer
    final double latPad = (bounds.northeast.latitude - bounds.southwest.latitude).abs() * 0.02;
    final double lngPad = (bounds.northeast.longitude - bounds.southwest.longitude).abs() * 0.02;

    return !(maxLat < bounds.southwest.latitude - latPad ||
             minLat > bounds.northeast.latitude + latPad ||
             maxLng < bounds.southwest.longitude - lngPad ||
             minLng > bounds.northeast.longitude + lngPad);
  }
}

ParsedRoadGeometry parseWKTWithBBox(String wkt) {
  final segments = parseWKTToSegments(wkt);
  if (segments.isEmpty) {
    return ParsedRoadGeometry(segments: [], minLat: 0, minLng: 0, maxLat: 0, maxLng: 0);
  }

  double minLat = 90.0, maxLat = -90.0;
  double minLng = 180.0, maxLng = -180.0;

  for (final seg in segments) {
    for (final p in seg) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
  }

  return ParsedRoadGeometry(
    segments: segments,
    minLat: minLat,
    minLng: minLng,
    maxLat: maxLat,
    maxLng: maxLng,
  );
}

List<ParsedRoadGeometry> parseWKTBatchWithBBox(List<String> wktList) {
  return wktList.map((wkt) => parseWKTWithBBox(wkt)).toList();
}

List<List<List<LatLng>>> parseWKTBatch(List<String> wktList) {
  return wktList.map((wkt) => parseWKTToSegments(wkt)).toList();
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
