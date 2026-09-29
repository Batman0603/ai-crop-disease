import 'package:flutter/material.dart';

import '../widgets/feature_card.dart';
import '../widgets/section_heading.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature will be available in a later phase.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // Brand header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.eco, color: colors.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CropCare',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your plant health assistant',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          // Main call to action
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.grass, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  'Keep your crops healthy',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check a plant leaf for possible diseases and explore helpful crop-care information.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => onNavigate(1),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Scan a plant'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: colors.primary,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const SectionHeading(title: 'Start with a photo'),
          const SizedBox(height: 12),

          // Camera and gallery actions
          Row(
            children: [
              Expanded(
                child: _PhotoActionCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a photo',
                  description: 'Use your camera',
                  onTap: () => _showComingSoon(context, 'Camera capture'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoActionCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose photo',
                  description: 'From your gallery',
                  onTap: () => _showComingSoon(context, 'Gallery selection'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const SectionHeading(title: 'Explore CropCare'),
          const SizedBox(height: 12),

          FeatureCard(
            icon: Icons.menu_book_outlined,
            title: 'Disease library',
            description: 'Learn about crop diseases and plant symptoms.',
            onTap: () => onNavigate(2),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.history,
            title: 'Scan history',
            description: 'Review your previous plant scans.',
            onTap: () => onNavigate(3),
          ),

          const SizedBox(height: 24),

          // Photo-taking tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: colors.onSecondaryContainer,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo tip',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use a clear, well-lit photo of the leaf. Keep the affected area in focus and avoid strong shadows.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Disease predictions are informational and may be uncertain. Consult a qualified agricultural expert when needed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoActionCard extends StatelessWidget {
  const _PhotoActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: 28),
              const SizedBox(height: 14),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
