/// US dollar → Philippine peso rate used to show certification prices
/// (mid-market rate on 2026-09-24). Update when the rate moves a lot.
const double kUsdToPhp = 62.72;

/// What a training link costs.
enum TrainingCost {
  /// Learning and the certificate/badge are free.
  free,

  /// Learning is free, but the certificate or exam is paid.
  freeToLearn,

  /// Requires payment.
  paid,
}

class TrainingResource {
  final String label;
  final String url;
  final TrainingCost cost;

  /// Short explanation of the cost, e.g. "Free to audit; the certificate
  /// requires payment."
  final String? costNote;

  /// Official price in US dollars (most certification exams are priced in
  /// USD), and what it's for, e.g. "exam" or "month".
  final double? priceUsd;
  final String? priceUnit;
  final String? provider;
  final String? type;

  bool get isFree => cost == TrainingCost.free;

  /// Approximate price in pesos, e.g. "≈ ₱9,410 per exam", or null.
  String? get pesoPrice {
    final usd = priceUsd;
    if (usd == null) return null;
    final php = (usd * kUsdToPhp / 10).round() * 10;
    final digits = php.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final unit = priceUnit ?? 'exam';
    return '≈ ₱$digits ${unit == 'month' ? '/ month' : 'per $unit'}';
  }

  const TrainingResource({
    required this.label,
    required this.url,
    this.cost = TrainingCost.paid,
    this.costNote,
    this.priceUsd,
    this.priceUnit,
    this.provider,
    this.type,
  });
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
