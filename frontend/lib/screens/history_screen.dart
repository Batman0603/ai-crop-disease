import 'dart:io';

import 'package:flutter/material.dart';

import '../services/scan_history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanHistoryEntry> _entries = const [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    ScanHistoryService.changes.addListener(_load);

    _load();
  }

  @override
  void dispose() {
    ScanHistoryService.changes.removeListener(_load);

    super.dispose();
  }

  Future<void> _load() async {
    final entries = await ScanHistoryService.getEntries();

    if (!mounted) return;

    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    if (_entries.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text(
          'This removes saved scan records and their stored '
          'images from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ScanHistoryService.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 170),
            Center(
              child: Icon(Icons.history, size: 72, color: Color(0xFF2E7D32)),
            ),
            SizedBox(height: 18),
            Center(
              child: Text(
                'No scans yet',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Completed plant scans will appear here. '
                'Start a scan from Detect.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _entries.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    '${_entries.length} saved scan'
                    '${_entries.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            );
          }

          final entry = _entries[index - 1];

          return _HistoryCard(entry: entry);
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final ScanHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final confidence = '${(entry.confidence * 100).toStringAsFixed(1)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(entry.imagePath),
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 76,
                    height: 76,
                    color: colors.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  );
                },
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.diseaseName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 4),

                  Text(entry.crop),

                  const SizedBox(height: 5),

                  Text(
                    '${_formatDate(entry.createdAt)}'
                    '  •  $confidence',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            Icon(
              entry.isHealthy
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_outlined,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }
}
