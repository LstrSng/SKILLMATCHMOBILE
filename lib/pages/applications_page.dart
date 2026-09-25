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
import '../widgets/widgets.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

enum _ApplicationFilter { all, active, interviewing, archived }

class _ApplicationsPageState extends State<ApplicationsPage> {
  bool _loading = true;
  String? _error;
  List<JobApplication> applications = const [];
  _ApplicationFilter _selectedFilter = _ApplicationFilter.all;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedQuery = '';

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = val.trim().toLowerCase());
    });
  }

  @override
  void initState() {
    super.initState();
    AppNavigation.currentTab.addListener(_onTabNavChanged);
    _initFromCacheAndLoad();
  }

  Future<void> _initFromCacheAndLoad() async {
    final cachedApps = await getCachedMyApplications();
    if (!mounted) return;
    if (cachedApps.isNotEmpty) {
      final cachedJobs = memoryCachedJobs ?? await getCachedJobsRaw();
      final companyByJobId = {
        for (final j in cachedJobs)
          (j['id'] as Object?)?.toString().trim() ?? '':
              (j['company'] as String?)?.trim() ?? '',
      };
      final list = cachedApps
          .map(
            (r) => JobApplication.fromJson(
              r,
              liveCompany:
                  companyByJobId[(r['jobId'] as Object?)?.toString().trim()],
            ),
          )
          .toList();
      if (mounted) {
        setState(() {
          applications = list;
          _loading = false;
        });
      }
    }
    await _load(silent: applications.isNotEmpty);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    AppNavigation.currentTab.removeListener(_onTabNavChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onTabNavChanged() {
    if (AppNavigation.activeTab == AppTab.applied && !_loading) {
      if (_error != null || applications.isEmpty) {
        _load();
      } else {
        _load(silent: true);
      }
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
              liveCompany:
                  companyByJobId[(r['jobId'] as Object?)?.toString().trim()],
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        applications = list;
        _loading = false;
        _error = null;
      });

      final activeCount = list.where((app) => app.canWithdraw).length;
      unawaited(
        NotificationStore.maybeAddWeeklyDigest(
          activeApplicationCount: activeCount,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (applications.isEmpty) {
          _error = e.toString();
        }
      });
    }
  }

  List<JobApplication> get _activeApplications =>
      applications.where((app) => app.canWithdraw).toList();

  List<JobApplication> get _interviewingApplications => applications
      .where(
        (app) =>
            app.currentStatus.toLowerCase() == 'interview' ||
            app.currentStatus.toLowerCase() == 'interviewing',
      )
      .toList();

  List<JobApplication> get _archivedApplications =>
      applications.where((app) => app.isClosed).toList();

  List<JobApplication> get _filteredApplications {
    List<JobApplication> base;
    switch (_selectedFilter) {
      case _ApplicationFilter.all:
        base = applications;
        break;
      case _ApplicationFilter.active:
        base = _activeApplications;
        break;
      case _ApplicationFilter.interviewing:
        base = _interviewingApplications;
        break;
      case _ApplicationFilter.archived:
        base = _archivedApplications;
        break;
    }

    if (_debouncedQuery.isEmpty) return base;
    final query = _debouncedQuery;
    return base
        .where(
          (app) =>
              app.jobTitle.toLowerCase().contains(query) ||
              app.company.toLowerCase().contains(query) ||
              app.currentStatus.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final filtered = _filteredApplications;

    return Scaffold(
      backgroundColor: tokens.scaffoldBackground,
      appBar: const AppTopBar(),
      body: _loading
          ? ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
                vertical: 16,
              ),
              itemCount: 3,
              itemBuilder: (context, _) => const CenteredFormWidth(
                maxWidth: 720,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: JobCardSkeleton(),
                ),
              ),
            )
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
              color: tokens.primary,
              child: CenteredFormWidth(
                maxWidth: 720,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.of(context).size.width > 600 ? 32 : 16,
                        16,
                        MediaQuery.of(context).size.width > 600 ? 32 : 16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PageHeroHeader(
                              icon: Icons.business_center_rounded,
                              eyebrow: 'Your job hunt',
                              title: 'Applications',
                              subtitle:
                                  'Track every stage of your job applications in one place.',
                              highlight: applications.isEmpty
                                  ? null
                                  : '${_activeApplications.length} active · ${applications.length} total',
                            ),
                            const SizedBox(height: 16),

                            // Search Box
                            Container(
                              decoration: BoxDecoration(
                                color: tokens.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tokens.cardBorderSoft,
                                ),
                                boxShadow: const [AppColors.subtleShadow],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search applications by role or company...',
                                  hintStyle: TextStyle(
                                    color: tokens.textSecondary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: tokens.primary,
                                    size: 20,
                                  ),
                                  suffixIcon:
                                      ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: _searchController,
                                        builder: (context, value, _) {
                                          if (value.text.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return IconButton(
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _searchDebounce?.cancel();
                                              _searchController.clear();
                                              setState(
                                                () => _debouncedQuery = '',
                                              );
                                            },
                                          );
                                        },
                                      ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Quick Filter Chips Bar
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    label: 'All (${applications.length})',
                                    filter: _ApplicationFilter.all,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label:
                                        'Active (${_activeApplications.length})',
                                    filter: _ApplicationFilter.active,
                                    icon: Icons.bolt_rounded,
                                    accentColor: tokens.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label:
                                        'Interviewing (${_interviewingApplications.length})',
                                    filter: _ApplicationFilter.interviewing,
                                    icon: Icons.video_camera_front_rounded,
                                    accentColor: const Color(0xFF8B5CF6),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label:
                                        'Archived (${_archivedApplications.length})',
                                    filter: _ApplicationFilter.archived,
                                    icon: Icons.archive_outlined,
                                    accentColor: tokens.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Applications List / Empty State
                    if (filtered.isEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 600
                              ? 32
                              : 16,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceMuted,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.business_center_outlined,
                                      size: 32,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedFilter == _ApplicationFilter.all
                                        ? 'No job applications found.'
                                        : 'No ${_selectedFilter.name} applications.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _selectedFilter ==
                                            _ApplicationFilter.archived
                                        ? 'Applications you withdraw or archive will be stored here.'
                                        : 'Find exciting job matches and submit your application to start tracking.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                  if (_selectedFilter !=
                                      _ApplicationFilter.archived) ...[
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          AppNavigation.switchTab(AppTab.jobs),
                                      icon: const Icon(
                                        Icons.explore_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Browse Job Matches'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 600
                              ? 32
                              : 16,
                        ),
                        sliver: SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _ApplicationCard(
                              application: filtered[index],
                              onChanged: () => _load(silent: true),
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required _ApplicationFilter filter,
    IconData? icon,
    Color? accentColor,
  }) {
    final tokens = context.appColors;
    final isSelected = _selectedFilter == filter;
    final effectiveAccent = accentColor ?? tokens.primary;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = filter);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (accentColor?.withValues(alpha: 0.12) ?? tokens.primarySoftBg)
              : tokens.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? effectiveAccent : tokens.cardBorderSoft,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected ? null : const [AppColors.subtleShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? effectiveAccent : tokens.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? effectiveAccent : tokens.textSecondary,
              ),
            ),
          ],
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
    if (!application.canWithdraw) {
      showAppToast(
        context,
        application.isHired
            ? 'Applications cannot be withdrawn once hired.'
            : 'This application is already closed.',
        type: AppToastType.warning,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Withdraw application?'),
          content: const Text(
            'Are you sure you want to withdraw this application? This action will archive your submission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
      showAppToast(context, 'Application withdrawn.', type: AppToastType.info);
    } catch (e) {
      if (!context.mounted) return;
      showAppToast(context, 'Could not withdraw: $e', type: AppToastType.error);
    }
  }

  void _showTimelineModal(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TimelineBottomSheet(application: application),
    );
  }

  Future<void> _openDetails(BuildContext context) async {
    HapticFeedback.selectionClick();
    Map<String, dynamic>? full;
    try {
      if (application.jobId.trim().isNotEmpty) {
        final cached = memoryCachedJobs ?? await getCachedJobsRaw();
        final jobs = cached.isNotEmpty ? cached : await fetchJobsRaw();
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
    final tokens = context.appColors;
    final initial = application.company.isNotEmpty
        ? application.company.substring(0, 1).toUpperCase()
        : 'J';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: tokens.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      application.company.isNotEmpty
                          ? '${application.company} • Applied ${application.dateApplied}'
                          : 'Applied ${application.dateApplied}',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
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

          // Multi-Stage Application Status Tracker
          _MultiStageTracker(status: application.currentStatus),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action Buttons Bar
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: tokens.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openDetails(context),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text(
                  'Job Details',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: tokens.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showTimelineModal(context),
                icon: const Icon(Icons.history_rounded, size: 15),
                label: const Text(
                  'Timeline Log',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (application.isHired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tokens.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: tokens.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hired',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.success,
                        ),
                      ),
                    ],
                  ),
                )
              else if (application.canWithdraw)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.danger,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _confirmWithdraw(context),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text(
                    'Withdraw',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final isDark = context.isDarkMode;

    Color bg;
    Color fg;
    Color border;

    switch (status) {
      case 'Applied':
        bg = tokens.primarySoftBg;
        fg = tokens.primary;
        border = isDark ? tokens.primary : const Color(0xFFBFDBFE);
        break;
      case 'Screening':
        bg = isDark ? const Color(0xFF2A200B) : const Color(0xFFFEF3C7);
        fg = isDark ? AppColors.warningLight : const Color(0xFFD97706);
        border = isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
        break;
      case 'Interview':
      case 'Interviewing':
        bg = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
        fg = isDark ? AppColors.verifiedDark : const Color(0xFF4F46E5);
        border = isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE);
        break;
      case 'Offer':
      case 'Hired':
        bg = AppColors.matchBgColor(100, isDark: isDark);
        fg = tokens.success;
        border = AppColors.matchBorderColor(100, isDark: isDark);
        break;
      case 'Rejected':
        bg = AppColors.matchBgColor(0, isDark: isDark);
        fg = tokens.danger;
        border = AppColors.matchBorderColor(0, isDark: isDark);
        break;
      case 'Withdrawn':
        bg = tokens.surfaceMuted;
        fg = tokens.textSecondary;
        border = tokens.cardBorderSoft;
        break;
      default:
        bg = tokens.surfaceMuted;
        fg = tokens.textSecondary;
        border = tokens.cardBorderSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

/// Multi-stage linear status tracker showing 4 stages + terminal state handling.
class _MultiStageTracker extends StatelessWidget {
  final String status;

  const _MultiStageTracker({required this.status});

  static const _stages = ['Applied', 'Screening', 'Interview', 'Offer'];

  int get _currentStageIndex {
    switch (status.toLowerCase()) {
      case 'applied':
        return 0;
      case 'screening':
        return 1;
      case 'interview':
      case 'interviewing':
        return 2;
      case 'offer':
      case 'hired':
        return 3;
      default:
        return 0;
    }
  }

  bool get _isTerminalSpecial =>
      status.toLowerCase() == 'rejected' || status.toLowerCase() == 'withdrawn';

  bool get _isHired => status.toLowerCase() == 'hired';

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final stageIndex = _currentStageIndex;

    if (_isTerminalSpecial) {
      final isRejected = status.toLowerCase() == 'rejected';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isRejected
              ? (context.isDarkMode
                    ? const Color(0xFF2A1515)
                    : const Color(0xFFFFF1F2))
              : tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRejected ? const Color(0xFFFECDD3) : tokens.cardBorderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isRejected ? Icons.cancel_rounded : Icons.archive_outlined,
              size: 16,
              color: isRejected ? tokens.danger : tokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRejected
                    ? 'Application was not selected to advance.'
                    : 'Application has been withdrawn and archived.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isRejected ? tokens.danger : tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < _stages.length; i++) ...[
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isCompleted =
                        i < stageIndex || (i == stageIndex && _isHired);
                    final lineColor = _isHired
                        ? tokens.success
                        : tokens.primary;

                    return Column(
                      children: [
                        Row(
                          children: [
                            // Left connecting line
                            Expanded(
                              child: i == 0
                                  ? const SizedBox.shrink()
                                  : Container(
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color: i <= stageIndex
                                            ? lineColor
                                            : tokens.cardBorderSoft,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                            ),

                            // Stage Dot
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? tokens.success
                                    : (i == stageIndex
                                          ? tokens.primary
                                          : tokens.surfaceMuted),
                                border: Border.all(
                                  color: isCompleted
                                      ? tokens.success
                                      : (i <= stageIndex
                                            ? tokens.primary
                                            : tokens.cardBorderSoft),
                                  width: 2,
                                ),
                                boxShadow: (i == stageIndex && !_isHired)
                                    ? [
                                        BoxShadow(
                                          color: tokens.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : (i == stageIndex
                                          ? Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                          : null),
                              ),
                            ),

                            // Right connecting line
                            Expanded(
                              child: i == _stages.length - 1
                                  ? const SizedBox.shrink()
                                  : Container(
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color:
                                            (i < stageIndex ||
                                                (i == stageIndex && _isHired))
                                            ? lineColor
                                            : tokens.cardBorderSoft,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stages[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: (i == stageIndex)
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isCompleted
                                ? (_isHired
                                      ? tokens.success
                                      : tokens.textPrimary)
                                : (i == stageIndex
                                      ? tokens.primary
                                      : tokens.textSecondary.withValues(
                                          alpha: 0.6,
                                        )),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        if (_isHired) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.success.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.celebration_rounded,
                  size: 15,
                  color: tokens.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "You've been hired! Congratulations on the offer.",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.success,
                    ),
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

/// Bottom sheet displaying timestamped activity timeline logs.
class _TimelineBottomSheet extends StatelessWidget {
  const _TimelineBottomSheet({required this.application});

  final JobApplication application;

  static String _formatTimestamp(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    final history = application.statusHistory.isNotEmpty
        ? application.statusHistory
        : [
            ApplicationStatusStep(
              status: application.currentStatus,
              date: application.appliedDate,
              note:
                  'Initial submission sent to ${application.company.isNotEmpty ? application.company : "employer"}.',
            ),
          ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: tokens.cardShadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.cardBorderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: tokens.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application Timeline Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            '${application.jobTitle} • ${application.company}',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Timeline Log items
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(history.length, (index) {
                  final step = history[index];
                  final isLast = index == history.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline track line + dot
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: tokens.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: tokens.cardBorderSoft,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Timeline details card
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _StatusBadge(status: step.status),
                                    const Spacer(),
                                    Text(
                                      _formatTimestamp(step.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (step.note.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    step.note,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
