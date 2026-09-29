import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.history,
          title: 'No scans yet',
          message: 'Your completed plant scans will appear here once scan history is implemented.',
        ),
      ),
    );
  }
}
