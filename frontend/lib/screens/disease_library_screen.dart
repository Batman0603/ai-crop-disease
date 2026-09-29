import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class DiseaseLibraryScreen extends StatelessWidget {
  const DiseaseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Disease library',
          message: 'Crop disease information and treatment guidance will be added in Phase 7.',
        ),
      ),
    );
  }
}
