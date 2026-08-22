import 'package:flutter/material.dart';

import '../models/training_pathway.dart';
import '../services/pathway_links_data.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/training_pathway_card.dart';

const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class PathwayPage extends StatefulWidget {
  const PathwayPage({super.key});

  @override
  State<PathwayPage> createState() => _PathwayPageState();
}

class _PathwayPageState extends State<PathwayPage> {
  bool _loading = true;
  String? _error;
  List<TrainingPathway> _pathways = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pathways = await allTrainingPathways();
      if (!mounted) return;
      setState(() {
        _pathways = pathways;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _pathways
        : _pathways.where((p) => p.name.toLowerCase().contains(q)).toList();
    final horizontalPadding = MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Certifications',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Browse skill areas and find where to get certified',
                style: TextStyle(fontSize: 16, color: _kGray),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search (e.g. Cloud, Cybersecurity, Java)',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching certification pathways.'))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    100,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _PathwayTile(
                    key: ValueKey(filtered[i].name),
                    pathway: filtered[i],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PathwayTile extends StatefulWidget {
  final TrainingPathway pathway;

  const _PathwayTile({super.key, required this.pathway});

  @override
  State<_PathwayTile> createState() => _PathwayTileState();
}

class _PathwayTileState extends State<_PathwayTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pathway = widget.pathway;
    final count = pathway.links.length;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pathway.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'No verified resources yet'
                          : '$count resource${count == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: _kGray),
                    ),
                  ],
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: _kGray,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 12),
            TrainingLinksList(pathway: pathway),
          ],
        ],
      ),
    );
  }
}
