import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'Screens/basic_screen/SplashScreen.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  // await FlutterMapTileCaching.initialise();
  // FMTC.instance('osm').manage.create(); // create a cache instance for OSM
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20; // 40 MB

  // 🛡️ Global Error Handlers - Prevents crash / grey screen
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint("🔴 UI Render Error Caught Gracefully: ${details.exception}");
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 42),
              SizedBox(height: 8),
              Text(
                "Unable to display view properly.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("🛡️ UNCAUGHT DART ERROR PREVENTED: $error");
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

