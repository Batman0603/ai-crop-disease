import 'package:flutter/material.dart';

import '../models/disease_information.dart';
import '../services/disease_information_service.dart';

class DiseaseLibraryScreen extends StatefulWidget {
  const DiseaseLibraryScreen({super.key});

  @override
  State<DiseaseLibraryScreen> createState() => _DiseaseLibraryScreenState();
}

class _DiseaseLibraryScreenState extends State<DiseaseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _cropFilter = 'All';

  List<DiseaseInformation> get _filteredDiseases {
    final query = _searchController.text.trim().toLowerCase();

    return DiseaseInformationService.all.where((disease) {
      final cropMatches = _cropFilter == 'All' || disease.crop == _cropFilter;

      final queryMatches =
          query.isEmpty ||
          disease.diseaseName.toLowerCase().contains(query) ||
          disease.crop.toLowerCase().contains(query);

      return cropMatches && queryMatches;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_refresh);
  }

  void _refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();

    super.dispose();
  }

  void _openDisease(DiseaseInformation disease) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _DiseaseDetailScreen(disease: disease)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diseases = _filteredDiseases;

    final crops = <String>{
      'All',
      ...DiseaseInformationService.all.map((disease) => disease.crop),
    }.toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search diseases or crops',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: crops.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final crop = crops[index];

                return ChoiceChip(
                  label: Text(crop),
                  selected: _cropFilter == crop,
                  onSelected: (selected) {
                    if (!selected) return;

                    setState(() {
                      _cropFilter = crop;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Text(
            '${diseases.length} conditions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          ...diseases.map(
            (disease) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DiseaseCard(
                disease: disease,
                onTap: () => _openDisease(disease),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({required this.disease, required this.onTap});

  final DiseaseInformation disease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final healthy = disease.isHealthy;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: healthy
                      ? colors.primaryContainer
                      : colors.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  healthy ? Icons.eco_outlined : Icons.coronavirus_outlined,
                  color: healthy ? colors.primary : colors.error,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.diseaseName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disease.crop,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiseaseDetailScreen extends StatelessWidget {
  const _DiseaseDetailScreen({required this.disease});

  final DiseaseInformation disease;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(disease.diseaseName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(disease.crop)),
                Chip(label: Text(disease.isHealthy ? 'Healthy' : 'Disease')),
              ],
            ),

            const SizedBox(height: 12),

            _Section(title: 'About', child: Text(disease.description)),

            if (disease.symptoms.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                title: 'Common symptoms',
                child: _Bullets(disease.symptoms),
              ),
            ],

            const SizedBox(height: 12),

            _Section(
              title: disease.isHealthy
                  ? 'Recommended care'
                  : 'Treatment & management',
              child: _Bullets(disease.treatment),
            ),

            const SizedBox(height: 16),

            Text(
              'Information is for decision support. '
              'Follow local agricultural guidance '
              'and product labels before treatment.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
