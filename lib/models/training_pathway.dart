class TrainingResource {
  final String label;
  final String url;
  final bool? _isFree;
  final String? provider;
  final String? type;

  bool get isFree => _isFree ?? label.toLowerCase().contains('free');

  const TrainingResource({
    required this.label,
    required this.url,
    bool? isFree,
    this.provider,
    this.type,
  }) : _isFree = isFree;
}

class TrainingPathway {
  final String name;
  final List<TrainingResource> links;
  final String note;
  final String? field;

  const TrainingPathway({
    required this.name,
    required this.links,
    required this.note,
    this.field,
  });
}
