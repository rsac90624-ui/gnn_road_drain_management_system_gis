import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'Screens/basic_screen/SplashScreen.dart';
import 'Screens/testing/debug_proxy_override.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // await FlutterMapTileCaching.initialise();
  // FMTC.instance('osm').manage.create(); // create a cache instance for OSM
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20; // 40 MB
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("UNCAUGHT: $error\n$stack");
    return true;
  };

  // if (!kReleaseMode) {
  //   HttpOverrides.global = DebugProxyOverride();
  // }


  // Force traffic to auditor proxy
  // HttpOverrides.global = DebugProxyOverride();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}

