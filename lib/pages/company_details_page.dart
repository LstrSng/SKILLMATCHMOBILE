import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';
import '../services/company_api.dart';
import '../widgets/app_card.dart';

class CompanyDetailsPage extends StatefulWidget {
  final String jobId;

  const CompanyDetailsPage({super.key, required this.jobId});

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = const {};

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
      final company = await fetchCompanyDetails(widget.jobId);
      if (!mounted) return;
      setState(() {
        _company = company;
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

  String _s(String key) => (_company[key] as Object?)?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final name = _s('name').isEmpty ? 'Unknown company' : _s('name');
    final bio = _s('bio');
    final website = _s('website');
    final location = _s('location');
    final contactNumber = _s('contactNumber');
    final logoUrl = _s('logoUrl');

    final infoItems = <_InfoItem>[
      if (location.isNotEmpty) _InfoItem(label: 'Location', value: location),
      if (website.isNotEmpty) _InfoItem(label: 'Website', value: website),
      if (contactNumber.isNotEmpty)
        _InfoItem(label: 'Contact', value: contactNumber),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 20),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _companyLogo(logoUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About $name',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  bio.isEmpty
                      ? 'This company has not shared an overview yet.'
                      : bio,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          if (infoItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < infoItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    infoItems[i],
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

Widget _companyLogo(String logoUrl, {double size = 60}) {
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(Icons.business, color: Colors.white, size: 30),
  );

  if (!logoUrl.startsWith('data:image')) return fallback;
  final comma = logoUrl.indexOf(',');
  if (comma <= -1 || comma + 1 >= logoUrl.length) return fallback;
  try {
    final bytes = base64Decode(logoUrl.substring(comma + 1));
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  } catch (_) {
    return fallback;
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
