import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class AppErrorUtils {
  /// Converts HTTP status code or Exception into a clear, user-friendly message.
  static String getFriendlyErrorMessage(int? statusCode, [dynamic exception]) {
    // 1. Handle Exception Types
    if (exception != null) {
      if (exception is SocketException || exception is ClientException) {
        return "Network connection issue. Please check your internet connection and try again.";
      }
      if (exception is TimeoutException) {
        return "Server request timed out. Please try again.";
      }
      if (exception is FormatException) {
        return "Received invalid response from server. Please try again later.";
      }

      final errStr = exception.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('clientexception')) {
        return "Network connection issue. Please check your internet connection and try again.";
      }
      if (errStr.contains('timeoutexception') || errStr.contains('timeout')) {
        return "Server request timed out. Please try again.";
      }
      if (errStr.contains('format') || errStr.contains('json')) {
        return "Received invalid response from server. Please try again later.";
      }
    }

    // 2. Handle HTTP Status Codes
    if (statusCode == null) {
      return "Something went wrong. Please try again.";
    }

    switch (statusCode) {
      case 400:
        return "Invalid request. Please verify the entered details and try again.";
      case 401:
        return "Session expired or invalid login. Please log in again.";
      case 403:
        return "Access denied. You do not have permission for this action.";
      case 404:
        return "Requested server endpoint or data was not found.";
      case 408:
        return "Request timed out. Please check your network connection and retry.";
      case 409:
        return "Conflict error. This record or entry already exists.";
      case 413:
        return "Selected file or photo size is too large. Please try again with smaller images.";
      case 500:
      case 502:
      case 503:
      case 504:
        return "Server error occurred while processing data.";
      default:
        return "Unable to complete request. Please try again later.";
    }
  }

  /// Formats raw Spring/Database exception messages into clean, professional English explanations.
  static String _formatRawServerException(String raw) {
    final lower = raw.toLowerCase();

    if (lower.contains("incorrect result size") ||
        lower.contains("dataaccessexception") ||
        lower.contains("nullablesingleresult")) {
      return "Multiple duplicate entries exist for this Road ID in the database, but the system expected a single unique record.";
    }

    if (lower.contains("duplicate key") ||
        lower.contains("unique constraint") ||
        lower.contains("already exists")) {
      return "A record with this ID already exists in the database. Duplicate entries are not allowed.";
    }

    if (lower.contains("foreign key") ||
        lower.contains("dataintegrityviolationexception")) {
      return "Database integrity error. The referenced Road ID, Zone, or Ward is missing or invalid in the database.";
    }

    if (lower.contains("nullpointerexception")) {
      return "Server processing error. One or more required fields were missing in the submission payload.";
    }

    if (lower.contains("badsqlgrammarexception") ||
        lower.contains("does not exist")) {
      return "Database schema mismatch. Please verify that server database tables and columns match the application model.";
    }

    return raw;
  }

  /// Extracts actual server error message from HTTP response body or Spring Boot exception payload.
  static String parseServerError(int statusCode, String responseBody) {
    if (responseBody.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map) {
          final serverMsg = decoded['message'] ?? decoded['error'] ?? decoded['exception'] ?? decoded['detail'];
          if (serverMsg != null && serverMsg.toString().trim().isNotEmpty) {
            return _formatRawServerException(serverMsg.toString().trim());
          }
        }
      } catch (_) {
        // Plain text / HTML response body
        String clean = responseBody
            .replaceAll(RegExp(r'<[^>]*>'), '') // Strip HTML tags
            .trim();
        if (clean.contains('Exception:')) {
          clean = clean.substring(clean.indexOf('Exception:') + 10).trim();
        }
        if (clean.isNotEmpty) {
          return _formatRawServerException(clean.length > 350 ? "${clean.substring(0, 350)}..." : clean);
        }
      }
    }
    return getFriendlyErrorMessage(statusCode);
  }

  /// Displays an AlertDialog Popup showing the actual server error details in professional English.
  static void showServerErrorDialog(BuildContext context, int statusCode, String responseBody) {
    if (!context.mounted) return;

    final String actualError = parseServerError(statusCode, responseBody);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Server Error Popup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Status Code: $statusCode",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
              ),
              const SizedBox(height: 10),
              const Text(
                "Actual Server Cause:",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    actualError,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
