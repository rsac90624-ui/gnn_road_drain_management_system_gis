// import 'dart:io';
//
// class DebugProxyOverride extends HttpOverrides {
//   @override
//   HttpClient createHttpClient(SecurityContext? context) {
//     final client = super.createHttpClient(context);
//
//     client.findProxy = (uri) {
//       return "PROXY 192.168.1.27:8083";
//     };
//
//     client.badCertificateCallback =
//         (X509Certificate cert, String host, int port) => true;
//
//     return client;
//   }
// }
