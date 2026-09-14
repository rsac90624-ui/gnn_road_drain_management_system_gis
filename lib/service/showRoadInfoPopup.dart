// // lib/widgets/road_info_popup.dart
//
// import 'package:flutter/material.dart';
//
// void showRoadInfoPopup(
//     BuildContext context,
//     Map<String, dynamic> roadData, {
//       required Function(Map<String, dynamic>) onConfirmRoad,
//       required Function(Map<String, dynamic>) onClearRoad,
//       bool isAlreadyConfirmed = false,
//       String? confirmedAt,
//     }) {
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
//                         onClearRoad(roadData);
//                       },
//                     ),
//                   ),
//
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
//
//                   Text("🆔 Road ID: ${roadData['road_id'] ?? 'N/A'}"),
//                   Text("📛 Name: ${roadData['road_name'] ?? 'N/A'}"),
//                   Text("📍 Zone: ${roadData['zone_name'] ?? 'N/A'}"),
//                   Text("🏘️ Ward: ${roadData['ward_no'] ?? 'N/A'}"),
//                   Text("🛣️ Category: ${roadData['category'] ?? 'N/A'}"),
//                   Text("📏 Length (m): ${roadData['length_met'] ?? 'N/A'}"),
//                   Text("🏗️ Condition: ${roadData['condition'] ?? 'N/A'}"),
//                   Text("📅 Year of Construction: ${roadData['yoc'] ?? 'N/A'}"),
//                   Text("🏥 Hospital: ${roadData['hospital'] ?? 'N/A'}"),
//                   Text("🏦 Bank: ${roadData['bank_atm'] ?? 'N/A'}"),
//                   Text("🏫 School: ${roadData['educationa'] ?? 'N/A'}"),
//
//                   const SizedBox(height: 16),
//
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       TextButton.icon(
//                         onPressed: () {
//                           Navigator.pop(context);
//                           onClearRoad(roadData);
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
//
//                       if (isAlreadyConfirmed)
//                         Column(
//                           children: [
//                             Text(
//                               "✅ Already confirmed on:",
//                               style: TextStyle(
//                                 color: Colors.green.shade700,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               confirmedAt ?? "Unknown",
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             ElevatedButton.icon(
//                               onPressed: null,
//                               icon: const Icon(Icons.check_circle_outline),
//                               label: const Text("Confirmed"),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.grey,
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
//                                         onClearRoad(roadData);
//                                       },
//                                     ),
//                                     TextButton(
//                                       child: const Text("Yes"),
//                                       onPressed: () {
//                                         Navigator.pop(dialogContext);
//                                         Navigator.pop(context);
//                                         onConfirmRoad(roadData);
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
//                             style: TextStyle(color: Colors.white, fontSize: 15),
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
