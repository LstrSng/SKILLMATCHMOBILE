class TrainingResource {
  final String label;
  final String url;

  const TrainingResource({required this.label, required this.url});
}

class TrainingPathway {
  final String name;
  final List<TrainingResource> links;
  final String note;

  const TrainingPathway({
    required this.name,
    required this.links,
    required this.note,
  });
}
