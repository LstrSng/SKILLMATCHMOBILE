import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/job_application.dart';
import '../services/applications_api.dart';
import '../services/jobs_api.dart';
import '../services/navigation_service.dart';
import '../services/notification_store.dart';
import '../services/session_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'job_detail_page.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/centered_form_width.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  bool _loading = true;
  bool _showWithdrawn = false;
  String? _error;
  List<JobApplication> applications = const [];

  List<JobApplication> get _activeApplications =>
      applications.where((app) => app.currentStatus != 'Withdrawn').toList();

  List<JobApplication> get _withdrawnApplications =>
      applications.where((app) => app.currentStatus == 'Withdrawn').toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final raw = await fetchMyApplications();
      await NotificationStore.syncApplicationUpdatesFromList(raw);

      final jobs = await fetchJobsRaw().catchError(
        (_) => <Map<String, dynamic>>[],
      );
      final companyByJobId = {
        for (final j in jobs)
          (j['id'] as Object?)?.toString().trim() ?? '':
              (j['company'] as String?)?.trim() ?? '',
      };

      final list = raw
          .map(
            (r) => JobApplication.fromJson(
              r,
              liveCompany: companyByJobId[(r['jobId'] as Object?)
                  ?.toString()
                  .trim()],
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        applications = list;
        _loading = false;
        _error = null;
      });
      final activeCount = list
          .where((app) => app.currentStatus != 'Withdrawn')
          .length;
      unawaited(
        NotificationStore.maybeAddWeeklyDigest(
          activeApplicationCount: activeCount,
        ),
      );
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
    final activeApplications = _activeApplications;
    final withdrawnApplications = _withdrawnApplications;
    final visibleApplications = _showWithdrawn
        ? withdrawnApplications
        : activeApplications;

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
                    FilledButton(
                      onPressed: () => _load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(silent: true),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
                  vertical: 16,
                ),
                child: CenteredFormWidth(
                  maxWidth: 700,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Segmented Controller
                      const Text(
                        'Applications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Track the status of all your job submissions',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Segmented Tab Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SegmentTab(
                                label: 'Active (${activeApplications.length})',
                                isSelected: !_showWithdrawn,
                                onTap: () => setState(() => _showWithdrawn = false),
                              ),
                            ),
                            Expanded(
                              child: _SegmentTab(
                                label: 'Withdrawn (${withdrawnApplications.length})',
                                isSelected: _showWithdrawn,
                                onTap: () => setState(() => _showWithdrawn = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (visibleApplications.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.business_center_outlined,
                                    size: 32,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showWithdrawn
                                      ? 'No withdrawn applications.'
                                      : 'No active applications yet.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _showWithdrawn
                                      ? 'Applications you withdraw will be archived here.'
                                      : 'Find exciting job matches and submit your application.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (!_showWithdrawn) ...[
                                  const SizedBox(height: 18),
                                  FilledButton.icon(
                                    onPressed: () => AppNavigation.switchTab(AppTab.jobs),
                                    icon: const Icon(Icons.explore_rounded, size: 18),
                                    label: const Text('Browse Job Matches'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: visibleApplications
                              .map(
                                (app) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _ApplicationCard(
                                    application: app,
                                    onChanged: () => _load(silent: true),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final JobApplication application;
  final Future<void> Function() onChanged;

  const _ApplicationCard({required this.application, required this.onChanged});

  Future<void> _confirmWithdraw(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Withdraw application?'),
          content: const Text(
            'Are you sure you want to withdraw this application?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await updateApplicationStatus(
        applicationId: application.id,
        status: 'Withdrawn',
      );
      await onChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application withdrawn.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not withdraw: $e')));
    }
  }

  Future<void> _openDetails(BuildContext context) async {
    Map<String, dynamic>? full;
    try {
      if (application.jobId.trim().isNotEmpty) {
        final jobs = await fetchJobsRaw();
        if (!context.mounted) return;
        for (final j in jobs) {
          final id = (j['id'] as Object?)?.toString().trim() ?? '';
          if (id == application.jobId.trim()) {
            full = j;
            break;
          }
        }
      }
    } catch (_) {}

    final snap = application.jobSnapshot;
    final data = full ?? snap;

    String s(String k) => (data[k] as Object?)?.toString().trim() ?? '';

    int n(String k) {
      final v = data[k];
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    List<String> list(String k) {
      final v = data[k];
      if (v is! List) return const [];
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (!context.mounted) return;
    final applicantId = (SessionStore.user?['_id'] ?? SessionStore.user?['id'])
        ?.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailPage(
          jobId: application.jobId,
          applicantId: applicantId,
          title: s('title').isEmpty ? application.jobTitle : s('title'),
          company: s('company').isEmpty ? application.company : s('company'),
          location: s('location'),
          salary: s('salary'),
          jobType: s('jobType'),
          postedDate: s('postedDate'),
          matchPercentage: n('matchPercentage'),
          description: s('description'),
          matchedSkills: list('matchedSkills'),
          unmatchedSkills: list('unmatchedSkills'),
          allowApply: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Center(
                  child: Text(
                    application.company.isNotEmpty
                        ? application.company.substring(0, 1).toUpperCase()
                        : 'J',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.jobTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      application.company.isNotEmpty
                          ? '${application.company} • Applied ${application.dateApplied}'
                          : 'Applied ${application.dateApplied}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: application.currentStatus),
            ],
          ),
          const SizedBox(height: 16),
          _ApplicationTimeline(status: application.currentStatus),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openDetails(context),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text(
                  'View Job Details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              if (application.currentStatus != 'Withdrawn')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _confirmWithdraw(context),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text(
                    'Withdraw',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _backgroundColor {
    switch (status) {
      case 'Applied':
        return const Color(0xFFEFF6FF);
      case 'Screening':
        return const Color(0xFFFEF3C7);
      case 'Interview':
        return const Color(0xFFEEF2FF);
      case 'Offer':
      case 'Hired':
        return const Color(0xFFECFDF5);
      case 'Rejected':
      case 'Withdrawn':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get _textColor {
    switch (status) {
      case 'Applied':
        return const Color(0xFF2563EB);
      case 'Screening':
        return const Color(0xFFD97706);
      case 'Interview':
        return const Color(0xFF4F46E5);
      case 'Offer':
      case 'Hired':
        return const Color(0xFF059669);
      case 'Rejected':
      case 'Withdrawn':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ApplicationTimeline extends StatelessWidget {
  final String status;

  const _ApplicationTimeline({required this.status});

  static const _steps = ['Applied', 'Screening', 'Interview', 'Offer'];

  int get _currentStepIndex {
    switch (status) {
      case 'Applied':
        return 0;
      case 'Screening':
        return 1;
      case 'Interview':
        return 2;
      case 'Offer':
      case 'Hired':
        return 3;
      case 'Rejected':
      case 'Withdrawn':
        return -1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _currentStepIndex;
    final isNegative = status == 'Rejected' || status == 'Withdrawn';

    return Row(
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: (!isNegative && i <= stepIndex)
                                  ? AppColors.primary
                                  : AppColors.borderSoft,
                            ),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isNegative
                            ? const Color(0xFFEF4444)
                            : (i <= stepIndex
                                ? AppColors.primary
                                : Colors.white),
                        border: Border.all(
                          color: isNegative
                              ? const Color(0xFFEF4444)
                              : (i <= stepIndex
                                  ? AppColors.primary
                                  : AppColors.borderSoft),
                          width: 2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: i == _steps.length - 1
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: (!isNegative && i < stepIndex)
                                  ? AppColors.primary
                                  : AppColors.borderSoft,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: (i == stepIndex) ? FontWeight.w700 : FontWeight.w500,
                    color: (i <= stepIndex && !isNegative)
                        ? AppColors.textPrimary
                        : AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
