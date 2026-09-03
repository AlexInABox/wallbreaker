import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOuiUpdateUrl =
    'https://raw.githubusercontent.com/jfisbein/ouidb-json/refs/heads/master/ouidb.json';
const _kLastUpdatedKey = 'oui_last_updated';
const _kDbFileName = 'ouidb_user.json';

class OuiInfo {
  final String organization;
  final String? country;

  OuiInfo({required this.organization, this.country});

  factory OuiInfo.fromJson(Map<String, dynamic> json) {
    final org = json['organization'] as Map<String, dynamic>;
    final address = org['address'] as Map<String, dynamic>?;
    return OuiInfo(
      organization: org['name'] as String,
      country: address?['countryCode'] as String?,
    );
  }
}

class OuiDatabase {
  static final OuiDatabase _instance = OuiDatabase._internal();
  factory OuiDatabase() => _instance;
  OuiDatabase._internal();

  Map<String, OuiInfo>? _db;
  bool _isLoading = false;
  bool get isLoaded => _db != null;

  /// Number of prefixes currently loaded.
  int get prefixCount => _db?.length ?? 0;

  /// Whether the database was ever updated through the app (vs bundled).
  bool _wasUpdatedByApp = false;
  bool get wasUpdatedByApp => _wasUpdatedByApp;

  /// True when the DB has never been updated through the app, or the last
  /// update was more than 7 days ago.
  bool get isStale {
    if (!_wasUpdatedByApp || _lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!).inDays >= 7;
  }

  /// ISO-8601 timestamp string of the last in-app update, or null.
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  Future<void> init() async {
    if (_db != null || _isLoading) return;
    _isLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString(_kLastUpdatedKey);
      if (tsStr != null) {
        _lastUpdated = DateTime.tryParse(tsStr);
        _wasUpdatedByApp = true;
      }

      // Try loading user-downloaded file first.
      final userFile = await _userDbFile();
      if (await userFile.exists()) {
        final jsonString = await userFile.readAsString();
        _db = _parse(jsonString);
        return;
      }

      // Fall back to bundled asset.
      final jsonString = await rootBundle.loadString('lib/ouidb.json');
      _db = _parse(jsonString);
    } catch (e) {
      _db = {};
    } finally {
      _isLoading = false;
    }
  }

  /// Downloads the latest OUI database from [_kOuiUpdateUrl] with progress.
  /// Calls [onProgress] with values 0.0–1.0.
  /// Throws on network/IO error.
  Future<void> update({required void Function(double) onProgress}) async {
    final request = http.Request('GET', Uri.parse(_kOuiUpdateUrl));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    int received = 0;
    final bytes = <int>[];

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (contentLength > 0) {
        onProgress((received / contentLength).clamp(0.0, 1.0));
      }
    }

    final jsonString = utf8.decode(bytes);
    // Validate JSON + parse before saving.
    final parsed = _parse(jsonString);

    // Persist to disk.
    final file = await _userDbFile();
    await file.writeAsString(jsonString, flush: true);

    // Record timestamp.
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastUpdatedKey, now.toIso8601String());

    // Hot-swap the in-memory database.
    _db = parsed;
    _lastUpdated = now;
    _wasUpdatedByApp = true;
  }

  OuiInfo? lookup(String macAddress) {
    final cleanMac = macAddress.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleanMac.length < 6) return null;
    final oui = cleanMac.substring(0, 6).toUpperCase();
    return _db?[oui];
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static Map<String, OuiInfo> _parse(String jsonString) {
    final List<dynamic> rawJson = jsonDecode(jsonString) as List<dynamic>;
    final Map<String, OuiInfo> parsedDb = {};
    for (var entry in rawJson) {
      if (entry is Map<String, dynamic>) {
        final prefix = entry['prefix'] as String?;
        if (prefix != null && prefix.length == 6) {
          parsedDb[prefix.toUpperCase()] = OuiInfo.fromJson(entry);
        }
      }
    }
    return parsedDb;
  }

  static Future<File> _userDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_kDbFileName');
  }
}

/// Converts a 2-letter country code to a flag emoji.
String getFlagEmoji(String countryCode) {
  if (countryCode.length != 2) return '';
  final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
}
