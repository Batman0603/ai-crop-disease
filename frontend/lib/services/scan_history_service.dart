import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanHistoryEntry {
  const ScanHistoryEntry({
    required this.id,
    required this.imagePath,
    required this.crop,
    required this.diseaseName,
    required this.confidence,
    required this.isHealthy,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final String crop;
  final String diseaseName;
  final double confidence;
  final bool isHealthy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'crop': crop,
      'diseaseName': diseaseName,
      'confidence': confidence,
      'isHealthy': isHealthy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      crop: json['crop'] as String,
      diseaseName: json['diseaseName'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      isHealthy: json['isHealthy'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ScanHistoryService {
  ScanHistoryService._();

  static const String _storageKey = 'cropcare_scan_history';

  static const int maxEntries = 50;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<List<ScanHistoryEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getStringList(_storageKey) ?? <String>[];

    final entries = <ScanHistoryEntry>[];

    for (final value in raw) {
      try {
        final entry = ScanHistoryEntry.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );

        if (await File(entry.imagePath).exists()) {
          entries.add(entry);
        }
      } catch (_) {
        // Ignore malformed history entries.
      }
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return entries;
  }

  static Future<void> addScan({
    required File sourceImage,
    required String crop,
    required String diseaseName,
    required double confidence,
    required bool isHealthy,
  }) async {
    final directory = await getApplicationDocumentsDirectory();

    final scansDirectory = Directory('${directory.path}/cropcare_scans');

    await scansDirectory.create(recursive: true);

    final now = DateTime.now();

    final id = now.microsecondsSinceEpoch.toString();

    final extension = _extensionOf(sourceImage.path);

    final destination = File('${scansDirectory.path}/$id$extension');

    await sourceImage.copy(destination.path);

    final entry = ScanHistoryEntry(
      id: id,
      imagePath: destination.path,
      crop: crop,
      diseaseName: diseaseName,
      confidence: confidence,
      isHealthy: isHealthy,
      createdAt: now,
    );

    final prefs = await SharedPreferences.getInstance();

    final existing = await getEntries();

    final retainedEntries = <ScanHistoryEntry>[entry, ...existing];

    final entriesToRemove = retainedEntries.length > maxEntries
        ? retainedEntries.sublist(maxEntries)
        : <ScanHistoryEntry>[];

    final retained = retainedEntries.take(maxEntries).toList();

    final values = retained.map((item) => jsonEncode(item.toJson())).toList();

    await prefs.setStringList(_storageKey, values);

    for (final oldEntry in entriesToRemove) {
      try {
        await File(oldEntry.imagePath).delete();
      } catch (_) {
        // Ignore files that are already missing.
      }
    }

    changes.value++;
  }

  static Future<void> clear() async {
    final entries = await getEntries();

    for (final entry in entries) {
      try {
        await File(entry.imagePath).delete();
      } catch (_) {
        // Ignore files that are already missing.
      }
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);

    changes.value++;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');

    if (dot == -1 || dot == path.length - 1) {
      return '.jpg';
    }

    final extension = path.substring(dot).toLowerCase();

    if (extension.length > 5) {
      return '.jpg';
    }

    return extension;
  }
}
