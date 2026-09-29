import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class DetectScreen extends StatelessWidget {
  const DetectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.document_scanner_outlined,
          title: 'Detect a plant disease',
          message: 'Camera capture and gallery image selection will be implemented in Phase 3.',
        ),
      ),
    );
  }
}
