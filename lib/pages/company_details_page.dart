import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/company_api.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast.dart';

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

  List<String> _photos() {
    final raw = _company['photos'];
    if (raw is List) {
      return raw.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _memberSinceLabel(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[parsed.month - 1]} ${parsed.year}';
  }

  Future<void> _launchOrCopy(String rawValue, String label, {String? customScheme}) async {
    if (rawValue.trim().isEmpty) return;
    final value = rawValue.trim();

    String urlToLaunch = value;
    if (customScheme == 'http') {
      if (!urlToLaunch.startsWith('http://') && !urlToLaunch.startsWith('https://')) {
        urlToLaunch = 'https://$urlToLaunch';
      }
    } else if (customScheme == 'mailto') {
      if (!urlToLaunch.startsWith('mailto:')) {
        urlToLaunch = 'mailto:$urlToLaunch';
      }
    } else if (customScheme == 'tel') {
      final digits = urlToLaunch.replaceAll(RegExp(r'[^0-9+]'), '');
      urlToLaunch = 'tel:$digits';
    }

    final uri = Uri.tryParse(urlToLaunch);
    bool launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) {
        showAppToast(context, '$label copied to clipboard', type: AppToastType.info);
      }
    }
  }

  void _shareCompany(String name, String website, String email, String location) {
    final buffer = StringBuffer('About $name:\n');
    if (location.isNotEmpty) buffer.writeln('📍 Location: $location');
    if (website.isNotEmpty) buffer.writeln('🌐 Website: $website');
    if (email.isNotEmpty) buffer.writeln('✉️ Email: $email');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showAppToast(context, 'Company details copied to clipboard', type: AppToastType.success);
  }

  void _openImageLightbox(String imageUrl, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _UniversalImage(
                imageSource: _ImageSource.parse(imageUrl),
                fit: BoxFit.contain,
                fallback: Container(
                  height: 240,
                  color: Colors.white10,
                  alignment: Alignment.center,
                  child: const Text('Could not load image', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
        title: const Text(
          'Company Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? _buildSkeletonLoading()
          : _error != null
              ? _buildErrorView()
              : _buildContent(context),
    );
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 160,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                color: AppColors.danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Company Details Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Could not fetch company details.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final rawName = _s('name');
    final name = rawName.isEmpty ? 'Company' : rawName;
    final bio = _s('bio');
    final website = _s('website');
    final location = _s('location');
    final contactNumber = _s('contactNumber');
    final logoUrl = _s('logoUrl');
    final bannerUrl = _s('bannerUrl');
    final email = _s('email');
    final contactName = _s('contactName');
    final industry = _s('industry');
    final companySize = _s('companySize');
    final memberSince = _memberSinceLabel(_s('memberSince'));
    final jobTitle = _s('jobTitle');
    final photos = _photos();

    final logoSource = _ImageSource.parse(logoUrl);
    final bannerSource = _ImageSource.parse(bannerUrl);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Card: Banner + Logo + Name + Badges
          _buildHeroCard(
            name: name,
            bannerSource: bannerSource,
            logoSource: logoSource,
            industry: industry,
            location: location,
            memberSince: memberSince,
          ),
          const SizedBox(height: 16),

          // 2. Quick Action Chips
          _buildQuickActionRow(
            website: website,
            email: email,
            phone: contactNumber,
            name: name,
            location: location,
          ),
          const SizedBox(height: 16),

          // 3. About / Overview Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.subject_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'About Company',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  bio.isEmpty
                      ? 'This company has not shared a detailed overview yet.'
                      : bio,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: bio.isEmpty ? AppColors.textFaint : const Color(0xFF475569),
                    height: 1.65,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Workplace Photos / Gallery (if available)
          if (photos.isNotEmpty) ...[
            _buildGalleryCard(photos, name),
            const SizedBox(height: 16),
          ],

          // 5. Company Info Card
          _buildCompanyInfoCard(
            location: location,
            website: website,
            contactNumber: contactNumber,
            email: email,
            contactName: contactName,
            industry: industry,
            companySize: companySize,
            memberSince: memberSince,
          ),

          // 6. Context Tag: Associated Job Posting
          if (jobTitle.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAssociatedJobCard(jobTitle),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required String name,
    required _ImageSource bannerSource,
    required _ImageSource logoSource,
    required String industry,
    required String location,
    required String memberSince,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Cover Banner
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  color: AppColors.primarySoftBg,
                  child: bannerSource.isValid
                      ? _UniversalImage(
                          imageSource: bannerSource,
                          fit: BoxFit.cover,
                          height: 140,
                          fallback: _buildDefaultBanner(),
                        )
                      : _buildDefaultBanner(),
                ),

                // Decorative Gradient Bottom Vignette
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.25),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Profile info with overlapping avatar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Overlapping Avatar
                  Transform.translate(
                    offset: const Offset(0, -38),
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1E000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.5),
                        child: SizedBox(
                          width: 76,
                          height: 76,
                          child: logoSource.isValid
                              ? _UniversalImage(
                                  imageSource: logoSource,
                                  fit: BoxFit.cover,
                                  fallback: _buildLogoFallback(name),
                                )
                              : _buildLogoFallback(name),
                        ),
                      ),
                    ),
                  ),

                  // Negative space adjustment for avatar
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Column(
                      children: [
                        // Company Name
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Industry / Verified Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            industry.isNotEmpty ? industry : 'Verified Employer',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Metadata Chips (Location & Member Since)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (location.isNotEmpty)
                              _buildHeroMetaChip(
                                icon: Icons.location_on_outlined,
                                label: location,
                              ),
                            if (memberSince.isNotEmpty)
                              _buildHeroMetaChip(
                                icon: Icons.calendar_today_outlined,
                                label: 'Member since $memberSince',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
            Color(0xFF3B82F6),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoFallback(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildHeroMetaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow({
    required String website,
    required String email,
    required String phone,
    required String name,
    required String location,
  }) {
    return Row(
      children: [
        if (website.isNotEmpty)
          Expanded(
            child: _buildActionBtn(
              icon: Icons.language_rounded,
              label: 'Website',
              color: const Color(0xFF2563EB),
              onTap: () => _launchOrCopy(website, 'Website', customScheme: 'http'),
            ),
          ),
        if (website.isNotEmpty && (email.isNotEmpty || phone.isNotEmpty))
          const SizedBox(width: 8),

        if (email.isNotEmpty)
          Expanded(
            child: _buildActionBtn(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              color: const Color(0xFF0D9488),
              onTap: () => _launchOrCopy(email, 'Email', customScheme: 'mailto'),
            ),
          ),
        if (email.isNotEmpty && phone.isNotEmpty)
          const SizedBox(width: 8),

        if (phone.isNotEmpty)
          Expanded(
            child: _buildActionBtn(
              icon: Icons.phone_outlined,
              label: 'Call',
              color: const Color(0xFF7C3AED),
              onTap: () => _launchOrCopy(phone, 'Contact Number', customScheme: 'tel'),
            ),
          ),
        if (phone.isNotEmpty || email.isNotEmpty || website.isNotEmpty)
          const SizedBox(width: 8),

        _buildIconActionBtn(
          icon: Icons.share_outlined,
          tooltip: 'Share Company',
          onTap: () => _shareCompany(name, website, email, location),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconActionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildGalleryCard(List<String> photos, String companyName) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF0D9488),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Workplace & Gallery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: photos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final photoUrl = photos[index];
                final photoSource = _ImageSource.parse(photoUrl);
                return GestureDetector(
                  onTap: () => _openImageLightbox(photoUrl, '$companyName Photo ${index + 1}'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 140,
                      color: AppColors.surfaceMuted,
                      child: _UniversalImage(
                        imageSource: photoSource,
                        fit: BoxFit.cover,
                        fallback: Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoCard({
    required String location,
    required String website,
    required String contactNumber,
    required String email,
    required String contactName,
    required String industry,
    required String companySize,
    required String memberSince,
  }) {
    final items = <_DetailRowData>[
      if (location.isNotEmpty)
        _DetailRowData(
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFF2563EB),
          label: 'Location',
          value: location,
          onTap: () => _launchOrCopy(location, 'Location'),
          isActionable: true,
        ),
      if (website.isNotEmpty)
        _DetailRowData(
          icon: Icons.language_rounded,
          iconColor: const Color(0xFF0284C7),
          label: 'Website',
          value: website,
          onTap: () => _launchOrCopy(website, 'Website', customScheme: 'http'),
          isActionable: true,
          actionIcon: Icons.open_in_new_rounded,
        ),
      if (contactNumber.isNotEmpty)
        _DetailRowData(
          icon: Icons.phone_outlined,
          iconColor: const Color(0xFF16A34A),
          label: 'Contact Number',
          value: contactNumber,
          onTap: () => _launchOrCopy(contactNumber, 'Contact Number', customScheme: 'tel'),
          isActionable: true,
          actionIcon: Icons.call_outlined,
        ),
      if (email.isNotEmpty)
        _DetailRowData(
          icon: Icons.mail_outline_rounded,
          iconColor: const Color(0xFFEA580C),
          label: 'Email',
          value: email,
          onTap: () => _launchOrCopy(email, 'Email', customScheme: 'mailto'),
          isActionable: true,
          actionIcon: Icons.send_rounded,
        ),
      if (contactName.isNotEmpty)
        _DetailRowData(
          icon: Icons.person_outline_rounded,
          iconColor: const Color(0xFF9333EA),
          label: 'Contact Person',
          value: contactName,
        ),
      if (industry.isNotEmpty)
        _DetailRowData(
          icon: Icons.category_outlined,
          iconColor: const Color(0xFF059669),
          label: 'Industry',
          value: industry,
        ),
      if (companySize.isNotEmpty)
        _DetailRowData(
          icon: Icons.people_outline_rounded,
          iconColor: const Color(0xFFD97706),
          label: 'Company Size',
          value: companySize,
        ),
      if (memberSince.isNotEmpty)
        _DetailRowData(
          icon: Icons.calendar_today_outlined,
          iconColor: const Color(0xFF475569),
          label: 'Member Since',
          value: memberSince,
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: Color(0xFF6366F1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Company Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.borderSoft),
              ),
            _buildDetailRow(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(_DetailRowData data) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: data.iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(data.icon, color: data.iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: data.isActionable ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (data.isActionable)
          Icon(
            data.actionIcon ?? Icons.copy_rounded,
            size: 16,
            color: AppColors.textFaint,
          ),
      ],
    );

    if (data.onTap != null) {
      return InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
  }

  Widget _buildAssociatedJobCard(String jobTitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Associated Job Posting',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jobTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRowData {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isActionable;
  final IconData? actionIcon;

  const _DetailRowData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
    this.isActionable = false,
    this.actionIcon,
  });
}

/// Helper model for parsing multiple image formats (Base64 data URI, raw base64, HTTP/HTTPS, relative paths).
class _ImageSource {
  final Uint8List? bytes;
  final String? networkUrl;
  final bool isValid;

  const _ImageSource._({this.bytes, this.networkUrl, required this.isValid});

  factory _ImageSource.parse(String? raw) {
    if (raw == null) return const _ImageSource._(isValid: false);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const _ImageSource._(isValid: false);

    // 1. Data URI: "data:image/...;base64,..."
    if (trimmed.startsWith('data:image')) {
      final comma = trimmed.indexOf(',');
      if (comma > -1 && comma + 1 < trimmed.length) {
        try {
          final decoded = base64Decode(trimmed.substring(comma + 1));
          if (decoded.isNotEmpty) {
            return _ImageSource._(bytes: decoded, isValid: true);
          }
        } catch (_) {}
      }
    }

    // 2. HTTP/HTTPS Network URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _ImageSource._(networkUrl: trimmed, isValid: true);
    }

    // 3. Relative backend path e.g. "/uploads/..." or "uploads/..."
    if (trimmed.startsWith('/') || trimmed.startsWith('uploads/')) {
      final base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return _ImageSource._(networkUrl: '$base$path', isValid: true);
    }

    // 4. Raw base64 string (no data:image prefix)
    if (trimmed.length > 50 && !trimmed.contains(' ') && !trimmed.contains('\n')) {
      try {
        final decoded = base64Decode(trimmed);
        if (decoded.isNotEmpty) {
          return _ImageSource._(bytes: decoded, isValid: true);
        }
      } catch (_) {}
    }

    return const _ImageSource._(isValid: false);
  }
}

/// Universal image widget that displays decoded bytes, remote URLs, or fallback smoothly.
class _UniversalImage extends StatelessWidget {
  final _ImageSource imageSource;
  final BoxFit fit;
  final double? height;
  final Widget fallback;

  const _UniversalImage({
    required this.imageSource,
    this.fit = BoxFit.cover,
    this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!imageSource.isValid) return fallback;

    if (imageSource.bytes != null) {
      return Image.memory(
        imageSource.bytes!,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    if (imageSource.networkUrl != null) {
      return Image.network(
        imageSource.networkUrl!,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            color: AppColors.surfaceMuted,
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.6),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return fallback;
  }
}
