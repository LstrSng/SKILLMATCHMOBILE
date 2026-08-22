class JobApplication {
  final String id;
  final String jobId;
  final String jobTitle;
  final String company;
  final String dateApplied;
  final DateTime appliedDate;
  final String currentStatus;
  final List<ApplicationStatusStep> statusHistory;
  final Map<String, dynamic> jobSnapshot;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.company,
    required this.dateApplied,
    required this.appliedDate,
    required this.currentStatus,
    required this.statusHistory,
    required this.jobSnapshot,
  });

  factory JobApplication.fromJson(
    Map<String, dynamic> json, {
    String? liveCompany,
  }) {
    final snap = json['jobSnapshot'] is Map
        ? Map<String, dynamic>.from(json['jobSnapshot'] as Map)
        : <String, dynamic>{};

    final rawTitle = (snap['title'] as Object?)?.toString().trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (json['jobTitle'] as Object?)?.toString().trim() ?? 'Untitled Application';

    final rawCompany = (snap['company'] as Object?)?.toString().trim();
    final company = (liveCompany != null && liveCompany.isNotEmpty)
        ? liveCompany
        : (rawCompany != null && rawCompany.isNotEmpty)
            ? rawCompany
            : (json['company'] as Object?)?.toString().trim() ?? '';

    final createdRaw = (json['createdAt'] as Object?)?.toString().trim() ?? '';
    final parsedCreated = DateTime.tryParse(createdRaw) ?? DateTime.now();

    final historyRaw = json['statusHistory'];
    final history = <ApplicationStatusStep>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(
            ApplicationStatusStep.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final rawStatus = (json['status'] as Object?)?.toString().trim() ?? 'Applied';
    final currentStatus = rawStatus.isEmpty ? 'Applied' : rawStatus;

    return JobApplication(
      id: (json['id'] as Object?)?.toString().trim() ??
          (json['_id'] as Object?)?.toString().trim() ??
          '',
      jobId: (json['jobId'] as Object?)?.toString().trim() ?? '',
      jobTitle: title,
      company: company,
      dateApplied: _formatDate(parsedCreated),
      appliedDate: parsedCreated,
      currentStatus: currentStatus,
      statusHistory: history,
      jobSnapshot: snap,
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class ApplicationStatusStep {
  final String status;
  final DateTime date;
  final String note;

  ApplicationStatusStep({
    required this.status,
    required this.date,
    this.note = '',
  });

  factory ApplicationStatusStep.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] as Object?)?.toString().trim() ??
        (json['updatedAt'] as Object?)?.toString().trim() ??
        '';
    return ApplicationStatusStep(
      status: (json['status'] as Object?)?.toString().trim() ?? 'Applied',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      note: (json['note'] as Object?)?.toString().trim() ?? '',
    );
  }
}
