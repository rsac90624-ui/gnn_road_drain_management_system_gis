import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'DrainageMapScreen.dart';
import 'SystemSelectionScreen.dart';
import 'Welcomescreen.dart';
import 'constants/appconstants.dart';
import 'models/asset_system.dart';

class RoadConditionScreen extends StatefulWidget {
  final AssetSystem system;
  final String? pointAssetType;

  const RoadConditionScreen({super.key, required this.system, this.pointAssetType,
  });

  @override
  _RoadConditionScreenState createState() => _RoadConditionScreenState();
}

class _RoadConditionScreenState extends State<RoadConditionScreen> {

  String username = "mobile_unknown";

  String get assetLabel {
    return widget.system == AssetSystem.road ? "Road" : "Drainage";
  }

  String get assetLabelPlural {
    return widget.system == AssetSystem.road ? "Roads" : "Drainage Lines";
  }

  final List<String> roadConditions = [
    'Roads between 1 to 5 years',
    'Roads greater than 5 years',
  ];

  final Map<String, String> roadConditionsMap = {
    'Roads between 1 to 5 years': 'between_1_5',
    'Roads greater than 5 years': 'greater_than_5',
  };

  String? selectedZone;

  String selectedWardNo = "";
  String selectedWardName = "";

  bool isLoadingZones = true;
  bool isLoadingWards = false;

  Set<String> selectedRoadConditions = {};

  List<Map<String, dynamic>> wards = [];
  List<String> zones = [];

  bool hasZone = true; // default safe value

  @override
  void initState() {
    super.initState();
    _loadSelections().then((_) {
      // Auto-load wards for previously selected zone
      if (selectedZone != null && selectedZone!.isNotEmpty) {
        fetchWards(selectedZone!);
      }
    });

    fetchZones();
    _loadUsername();

  }


  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString("username") ?? "mobile_unknown";
    });
  }

  Future<void> _loadSelections() async {
    final prefs = await SharedPreferences.getInstance();

    selectedZone = prefs.getString('selectedZone');
    selectedWardNo = prefs.getString('selectedWardNo') ?? "";
    selectedWardName = prefs.getString('selectedWardName') ?? "";

    List<String>? storedConditions = prefs.getStringList(
      'selectedRoadConditions',
    );
    if (storedConditions != null) {
      selectedRoadConditions = Set<String>.from(storedConditions);
    }

    setState(() {});
  }

  Future<void> _saveToPrefs(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }
  // Future<void> fetchZones() async {
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   final String nagarNigam =
  //   (prefs.getString('city') ??
  //       prefs.getString('nagarNigam') ??
  //       '')
  //       .trim();
  //
  //   debugPrint(
  //     "🏙️ FETCH ZONES CITY: [$nagarNigam]",
  //   );
  //
  //   if (nagarNigam.isEmpty) {
  //     setState(() {
  //       isLoadingZones = false;
  //       hasZone = false;
  //       zones = [];
  //     });
  //
  //     return;
  //   }
  //
  //   final url = Uri.parse(
  //     '${AppConstants.baseURL}api/roads_mobile/zones',
  //   ).replace(
  //     queryParameters: {
  //       'nagarNigam': nagarNigam,
  //     },
  //   );
  //
  //   debugPrint(
  //     "🏙️ ZONE URL: $url",
  //   );
  //
  //   try {
  //     final token =
  //     prefs.getString('authToken');
  //
  //     final response =
  //     await http.get(
  //       url,
  //       headers: {
  //         'Accept': 'application/json',
  //
  //         if (token != null &&
  //             token.trim().isNotEmpty)
  //           'Authorization':
  //           'Bearer ${token.trim()}',
  //       },
  //     );
  //
  //     debugPrint(
  //       "🏙️ ZONES STATUS: ${response.statusCode}",
  //     );
  //
  //     debugPrint(
  //       "🏙️ ZONES BODY: ${response.body}",
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> data =
  //       jsonDecode(response.body);
  //
  //       final List<String> fetchedZones =
  //       (data['zones'] as List? ?? [])
  //           .map(
  //             (e) => e
  //             .toString()
  //             .trim(),
  //       )
  //           .where(
  //             (e) =>
  //         e.isNotEmpty &&
  //             e.toUpperCase() != 'NA' &&
  //             e != '-',
  //       )
  //           .toSet()
  //           .toList();
  //
  //       if (!mounted) return;
  //
  //       setState(() {
  //         zones = fetchedZones;
  //
  //         // 🔥 IMPORTANT FIX
  //         // Do not rely only on backend hasZone.
  //         hasZone =
  //             fetchedZones.isNotEmpty;
  //
  //         isLoadingZones = false;
  //       });
  //
  //       debugPrint(
  //         "🏙️ FINAL ZONES: $zones",
  //       );
  //
  //       debugPrint(
  //         "🏙️ FINAL hasZone: $hasZone",
  //       );
  //
  //       // City really has no zones
  //       if (fetchedZones.isEmpty) {
  //         await fetchWardsWithoutZone();
  //       }
  //
  //       return;
  //     }
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       isLoadingZones = false;
  //       hasZone = false;
  //       zones = [];
  //     });
  //   } catch (e) {
  //     debugPrint(
  //       "❌ FETCH ZONES ERROR: $e",
  //     );
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       isLoadingZones = false;
  //       hasZone = false;
  //       zones = [];
  //     });
  //   }
  // }


  Future<void> fetchZones() async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city');
    debugPrint(nagarNigam);

    final url = Uri.parse(
      '${AppConstants.baseURL}api/roads_mobile/zones?nagarNigam=$nagarNigam',
    );
    debugPrint("zone URL : " + url.toString());


    try {
      final token = prefs.getString('authToken');

      debugPrint("CITY FROM PREFS: [$nagarNigam]");
      debugPrint("TOKEN FROM PREFS: [$token]");
      debugPrint("TOKEN EXISTS: ${token != null && token.isNotEmpty}");

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      debugPrint("Zones status: ${response.statusCode}");
      debugPrint("Zones body: ${response.body}");
      if (response.statusCode == 200) {

        final Map<String, dynamic> data = json.decode(response.body);

        setState(() {
          hasZone = data['hasZone'] ?? true;
          zones = List<String>.from(data['zones'] ?? []);
          isLoadingZones = false;
        });

        // 🔑 If city has NO zone → load wards directly
        if (!hasZone) {
          fetchWardsWithoutZone();
        }
      } else {
        setState(() => isLoadingZones = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingZones = false);
    }
  }

  Future<void> fetchWardsWithoutZone() async {
    setState(() {
      isLoadingWards = true;
      wards = [];
      selectedWardNo = "";
      selectedWardName = "";
    });

    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city');

    final url = Uri.parse(
      '${AppConstants.baseURL}api/roads_mobile/wards/by-city?nagarNigam=$nagarNigam',
    );
    debugPrint("wards URL : " + url.toString());

    try {
      final token = prefs.getString('authToken');
      debugPrint("WARDS TOKEN: [$token]");
      debugPrint("WARDS TOKEN EXISTS: ${token != null && token.isNotEmpty}");
      debugPrint("WARDS URL: $url");

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          wards = data.map<Map<String, dynamic>>((e) {
            return {
              "ward_no": (e["ward_no"] ?? e["wardNo"] ?? "").toString().trim(),
              "ward_name": (e["ward_name"] ?? e["wardName"] ?? "").toString().trim(),
            };
          }).where((e) =>
          e["ward_no"].isNotEmpty &&
              e["ward_name"].isNotEmpty &&
              e["ward_no"].toUpperCase() != "NA" &&
              e["ward_name"].toUpperCase() != "NA"
          ).toList();
        });

      }
    } finally {
      if (mounted) {
        setState(() => isLoadingWards = false);
      }
    }
  }

  Future<void> fetchWards(String zoneName) async {
    setState(() {
      isLoadingWards = true;
      wards = [];
      selectedWardNo = "";
      selectedWardName = "";
    });

    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city');

    final url = Uri.parse(
      '${AppConstants.baseURL}api/roads_mobile/wards?nagarNigam=$nagarNigam&zoneName=$zoneName',
    );

    debugPrint("wards URL : " + url.toString());

    try {
      final token = prefs.getString('authToken');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          wards = data.map<Map<String, dynamic>>((e) {
            return {
              "ward_no": (e["ward_no"] ?? e["wardNo"] ?? "").toString().trim(),
              "ward_name": (e["ward_name"] ?? e["wardName"] ?? "").toString().trim(),
            };
          }).where((e) =>
          e["ward_no"].isNotEmpty &&
              e["ward_name"].isNotEmpty &&
              e["ward_no"].toUpperCase() != "NA" &&
              e["ward_name"].toUpperCase() != "NA"
          ).toList();
        });

      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => isLoadingWards = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SystemSelectionScreen()),
        );
      },
      child: buildMainUI(),
    );
  }

  Widget buildMainUI() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      resizeToAvoidBottomInset: true, // ✅ add this

      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            // padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$assetLabel Selection Category',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select the zone name, ward number and construction year of the $assetLabel.',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),

                if (hasZone) ...[
                  _buildSelectionField(
                    "Zone Name",
                    Icons.location_city,
                    selectedZone ?? "",
                    _showZoneSelectionDialog,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                _buildSelectionField(
                  "Ward Number",
                  Icons.account_balance,
                  selectedWardNo.isEmpty
                      ? ""
                      : "$selectedWardNo - $selectedWardName",
                  isLoadingWards ? () {} : _showWardSelectionDialog,
                ),


                if (widget.system == AssetSystem.road) ...[
                  const SizedBox(height: 16),

                  Text(
                    'Select Year of Construction:',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Column(
                    children: roadConditions.map((condition) {
                      return CheckboxListTile(
                        title: Text(
                          condition,
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                        value: selectedRoadConditions.contains(
                          roadConditionsMap[condition],
                        ),
                        onChanged: (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              selectedRoadConditions.add(
                                roadConditionsMap[condition]!,
                              );
                            } else {
                              selectedRoadConditions.remove(
                                roadConditionsMap[condition]!,
                              );
                            }

                            _saveToPrefs(
                              'selectedRoadConditions',
                              selectedRoadConditions.toList(),
                            );
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Colors.orange,
                      );
                    }).toList(),
                  ),
                ],

                // const Spacer(),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),

                    onPressed:
                        (selectedWardNo.isNotEmpty &&
                            (!hasZone || selectedZone != null) &&
                            (widget.system == AssetSystem.drainage ||
                                selectedRoadConditions.isNotEmpty))
                        ? () {
                            if (widget.system == AssetSystem.road) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Welcomescreen(
                                    roadAgeCategory: selectedRoadConditions
                                        .toList(),
                                    zoneName: hasZone ? selectedZone! : null,
                                    wardNo: selectedWardNo,
                                    wardName: selectedWardName,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DrainageMapScreen(
                                    zoneName: hasZone ? selectedZone : null,
                                    wardNo: selectedWardNo,
                                    wardName: selectedWardName,
                                    username: username, // ✅ ADD THIS

                                  ),
                                ),
                              );
                            }
                          }
                        : null,

                    child: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionField(
    String label,
    IconData icon,
    String value,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFFE65100),
            fontWeight: FontWeight.w600,
          ),
          readOnly: true,
          decoration: _inputDecoration(label, icon),
          controller: TextEditingController(text: value),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Color(0xFFE65100)),
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFE65100)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  void _showZoneSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFFFFF8E1),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Column(
              children: [
                const Text(
                  "Select Zone",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.separated(
                    itemCount: zones.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFFE65100)),
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      return ListTile(
                        title: Text(
                          zone,
                          style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 16,
                          ),
                        ),
                        trailing: zone == selectedZone
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.orange,
                              )
                            : null,
                        onTap: () async {
                          setState(() {
                            selectedZone = zone;
                            selectedWardNo = "";
                            selectedWardName = "";
                            wards = [];
                          });

                          await _saveToPrefs('selectedZone', zone);
                          await _saveToPrefs('selectedWardNo', "");
                          await _saveToPrefs('selectedWardName', "");

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          // 🔥 THIS IS THE MISSING PIECE
                          fetchWards(zone);
                        },

                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showWardSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFFFFF8E1),
      builder: (context) {
        final TextEditingController searchController = TextEditingController();

        List<Map<String, dynamic>> filteredWards = List.from(wards);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void _filterWards(String query) {
              final q = query.trim().toLowerCase();

              setModalState(() {
                filteredWards = wards.where((ward) {
                  final wardName =
                  ward["ward_name"].toString().toLowerCase();
                  final wardNo =
                  ward["ward_no"].toString().toLowerCase();

                  return wardName.contains(q) || wardNo.contains(q);
                }).toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    const Text(
                      "Select Ward",
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: searchController,
                      onChanged: _filterWards,
                      cursorColor: const Color(0xFFE65100),
                      style: const TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search ward name or number",
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFE65100),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFFF3E0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView.separated(
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredWards.length,
                        separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFFE65100)),
                        itemBuilder: (context, index) {
                          final ward = filteredWards[index];
                          final wardNo = ward["ward_no"];
                          final wardName = ward["ward_name"];

                          return ListTile(
                            title: Text(
                              "$wardNo - $wardName",
                              style: const TextStyle(
                                color: Color(0xFFE65100),
                                fontSize: 16,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                selectedWardNo = wardNo;
                                selectedWardName = wardName;
                              });

                              _saveToPrefs('selectedWardNo', wardNo);
                              _saveToPrefs('selectedWardName', wardName);

                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


}
