import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/jobs_api.dart';
import '../services/navigation_service.dart';
import '../services/notification_store.dart';
import '../services/session_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'job_detail_page.dart';
import '../widgets/widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

enum _NotificationCategory { all, applications, jobMatches, system }

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  List<AppNotification> _notifications = const [];
  _NotificationCategory _selectedCategory = _NotificationCategory.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await NotificationStore.syncApplicationUpdates();
    } catch (_) {
      // Keep showing stored notifications even if live sync fails.
    }

    final notifications = await NotificationStore.load();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.selectionClick();
    await NotificationStore.markAllRead();
    final updated = await NotificationStore.load();
    if (!mounted) return;
    setState(() => _notifications = updated);
    showAppToast(context, 'All notifications marked as read.', type: AppToastType.success);
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear all notifications?'),
          content: const Text('This will remove all notification history on this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    await NotificationStore.clearAll();
    if (!mounted) return;
    setState(() => _notifications = []);
    showAppToast(context, 'Notifications cleared.', type: AppToastType.info);
  }

  Future<void> _handleNotificationAction(AppNotification notification) async {
    HapticFeedback.lightImpact();
    await NotificationStore.markRead(notification.id);
    _load();

    if (!mounted) return;

    if (notification.type == 'application' || notification.type == 'weekly_digest') {
      Navigator.pop(context);
      AppNavigation.switchTab(AppTab.applied);
      return;
    }

    if (notification.type == 'job_match') {
      if (notification.targetId != null && notification.targetId!.isNotEmpty) {
        // Try opening specific job
        try {
          final jobs = await fetchJobsRaw();
          final target = jobs.firstWhere(
            (j) => (j['id'] as Object?)?.toString().trim() == notification.targetId!.trim(),
            orElse: () => <String, dynamic>{},
          );
          if (target.isNotEmpty && mounted) {
            final applicantId = (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JobDetailPage(
                  jobId: notification.targetId!,
                  applicantId: applicantId,
                  title: target['title']?.toString() ?? 'Job Match',
                  company: target['company']?.toString() ?? '',
                  location: target['location']?.toString() ?? '',
                  salary: target['salary']?.toString() ?? '',
                  jobType: target['jobType']?.toString() ?? '',
                  postedDate: target['postedDate']?.toString() ?? '',
                  matchPercentage: target['matchPercentage'] is num
                      ? (target['matchPercentage'] as num).toInt()
                      : (int.tryParse(target['matchPercentage']?.toString() ?? '') ?? 0),
                  description: target['description']?.toString() ?? '',
                  matchedSkills: (target['matchedSkills'] as List?)?.map((e) => e.toString()).toList() ?? [],
                  unmatchedSkills: (target['unmatchedSkills'] as List?)?.map((e) => e.toString()).toList() ?? [],
                ),
              ),
            );
            return;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      // Default fallback for job matches
      Navigator.pop(context);
      AppNavigation.switchTab(AppTab.jobs);
    }
  }

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  List<AppNotification> get _filteredNotifications {
    switch (_selectedCategory) {
      case _NotificationCategory.all:
        return _notifications;
      case _NotificationCategory.applications:
        return _notifications.where((n) => n.type == 'application' || n.type == 'weekly_digest').toList();
      case _NotificationCategory.jobMatches:
        return _notifications.where((n) => n.type == 'job_match').toList();
      case _NotificationCategory.system:
        return _notifications.where((n) => n.type == 'system').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: tokens.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: tokens.cardBackground,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.done_all_rounded, color: tokens.primary, size: 20),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: tokens.textSecondary, size: 20),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: tokens.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
                  vertical: 16,
                ),
                children: [
                  CenteredFormWidth(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryChip(
                                label: 'All (${_notifications.length})',
                                category: _NotificationCategory.all,
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryChip(
                                label: 'Applications',
                                category: _NotificationCategory.applications,
                                icon: Icons.assignment_turned_in_rounded,
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryChip(
                                label: 'Job Matches',
                                category: _NotificationCategory.jobMatches,
                                icon: Icons.explore_rounded,
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryChip(
                                label: 'System',
                                category: _NotificationCategory.system,
                                icon: Icons.notifications_none_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceMuted,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications_none_rounded,
                                      color: tokens.textSecondary,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedCategory == _NotificationCategory.all
                                        ? 'No notifications yet.'
                                        : 'No notifications in this category.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Updates on your applications and job recommendations will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filtered.map(
                            (notification) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NotificationCard(
                                notification: notification,
                                timeAgo: _timeAgo(notification.createdAt),
                                onAction: () => _handleNotificationAction(notification),
                                onDismiss: () async {
                                  await NotificationStore.delete(notification.id);
                                  _load();
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required _NotificationCategory category,
    IconData? icon,
  }) {
    final tokens = context.appColors;
    final isSelected = _selectedCategory == category;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = category);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tokens.primarySoftBg : tokens.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? tokens.primary : tokens.cardBorderSoft,
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
                color: isSelected ? tokens.primary : tokens.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? tokens.primary : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.timeAgo,
    required this.onAction,
    required this.onDismiss,
  });

  final AppNotification notification;
  final String timeAgo;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    // Type visual tokens
    IconData icon;
    LinearGradient gradient;
    String actionLabel = notification.actionLabel ?? 'View Details';

    switch (notification.type) {
      case 'application':
        icon = Icons.assignment_turned_in_rounded;
        gradient = tokens.primaryGradient;
        actionLabel = notification.actionLabel ?? 'View Application';
        break;
      case 'job_match':
        icon = Icons.explore_rounded;
        gradient = const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        actionLabel = notification.actionLabel ?? 'Explore Job';
        break;
      case 'weekly_digest':
        icon = Icons.insights_rounded;
        gradient = const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        actionLabel = notification.actionLabel ?? 'View Digest';
        break;
      default:
        icon = Icons.notifications_rounded;
        gradient = const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        actionLabel = notification.actionLabel ?? 'View';
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient Icon Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),

              // Title & Message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tokens.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: tokens.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: tokens.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                label: Text(
                  actionLabel,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: tokens.textSecondary),
                tooltip: 'Dismiss',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
