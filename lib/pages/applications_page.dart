import 'package:flutter/material.dart';

import '../services/applications_api.dart';
import '../services/jobs_api.dart';
import '../services/notification_store.dart';
import '../services/session_store.dart';
import 'job_detail_page.dart';
import 'settings_page.dart';
import '../widgets/notification_bell_button.dart';

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
      final list = raw.map(JobApplication.fromJson).toList();

      if (!mounted) return;
      setState(() {
        applications = list;
        _loading = false;
        _error = null;
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
    final activeApplications = _activeApplications;
    final withdrawnApplications = _withdrawnApplications;
    final visibleApplications = _showWithdrawn
        ? withdrawnApplications
        : activeApplications;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const NotificationBellButton(),
          const SizedBox(width: 8),
        ],
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Applications',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track status of your job applications',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                    ),
                    if (withdrawnApplications.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showWithdrawn = !_showWithdrawn;
                          });
                        },
                        icon: Icon(
                          _showWithdrawn
                              ? Icons.list_alt
                              : Icons.visibility_outlined,
                        ),
                        label: Text(
                          _showWithdrawn
                              ? 'View Active Applications'
                              : 'View Withdrawn Applications (${withdrawnApplications.length})',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (visibleApplications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No applications to show in this list.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: visibleApplications
                            .map(
                              (app) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _ApplicationCard(
                                  application: app,
                                  onChanged: () => _load(silent: true),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 100),
                  ],
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
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await updateApplicationStatus(
      applicationId: application.id,
      status: 'Withdrawn',
    );
    await onChanged();
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
          backLabel: 'Back to Applications',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.jobTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${application.company} • ${application.dateApplied}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                ),
                onPressed: () => _openDetails(context),
                child: const Text(
                  'Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                ),
                onPressed: application.currentStatus == 'Withdrawn'
                    ? null
                    : () => _confirmWithdraw(context),
                child: const Text(
                  'Withdraw',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
        return const Color(0xFFDEEEFF);
      case 'Offer':
        return const Color(0xFFDCFCE7);
      case 'Rejected':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  Color get _textColor {
    switch (status) {
      case 'Applied':
        return const Color(0xFF2563EB);
      case 'Screening':
        return const Color(0xFFB45309);
      case 'Interview':
        return const Color(0xFF2563EB);
      case 'Offer':
        return const Color(0xFF10B981);
      case 'Rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}

class _ApplicationTimeline extends StatelessWidget {
  final String status;

  const _ApplicationTimeline({required this.status});

  bool _isCompleted(String stage) {
    const stages = ['Applied', 'Screening', 'Interview', 'Offer'];
    final currentIndex = stages.indexOf(status);
    final stageIndex = stages.indexOf(stage);
    return stageIndex <= currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    const stages = ['Applied', 'Screening', 'Interview', 'Offer'];
    final timelineChildren = <Widget>[];

    for (int i = 0; i < stages.length; i++) {
      timelineChildren.add(
        Expanded(
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _isCompleted(stages[i])
                    ? const Color(0xFF00D9A3)
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      );

      if (i < stages.length - 1) {
        timelineChildren.add(
          Expanded(
            child: Container(
              height: 2,
              color: _isCompleted(stages[i + 1])
                  ? const Color(0xFF00D9A3)
                  : const Color(0xFFE5E7EB),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: timelineChildren),
        const SizedBox(height: 8),
        Row(
          children: stages
              .map(
                (stage) => Expanded(
                  child: Center(
                    child: Text(
                      stage,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isCompleted(stage)
                            ? const Color(0xFF00D9A3)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String company;
  final String dateApplied;
  final String currentStatus;
  final DateTime appliedDate;
  final Map<String, dynamic> jobSnapshot;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.company,
    required this.dateApplied,
    required this.currentStatus,
    required this.appliedDate,
    required this.jobSnapshot,
  });

  static String _fmtDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final snap = json['jobSnapshot'];
    final s = snap is Map ? snap : const {};
    final snapMap = s.map((k, v) => MapEntry(k.toString(), v));
    final createdAtRaw = json['createdAt'];
    DateTime createdAt = DateTime.now();
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? createdAt;
    }

    return JobApplication(
      id: (json['_id'] as String?) ?? '',
      jobId: (json['jobId'] as Object?)?.toString().trim() ?? '',
      jobTitle: (s['title'] as String?)?.trim() ?? 'Untitled role',
      company: (s['company'] as String?)?.trim() ?? '',
      dateApplied: _fmtDate(createdAt),
      currentStatus: (json['status'] as String?)?.trim() ?? 'Applied',
      appliedDate: createdAt,
      jobSnapshot: snapMap,
    );
  }
}
