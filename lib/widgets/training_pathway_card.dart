import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/training_pathway.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'app_card.dart';
import 'app_toast.dart';

Future<void> _launchTrainingLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showAppToast(context, 'Could not open link.', type: AppToastType.error);
  }
}

/// The tappable list of verified training/certification links for a
/// pathway, plus its "no official cert body" note when present. No card
/// chrome of its own — embed it inside whatever card/section it belongs
/// to (see [TrainingPathwayCard] for a standalone version).
class TrainingLinksList extends StatelessWidget {
  const TrainingLinksList({super.key, required this.pathway});

  final TrainingPathway pathway;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...pathway.links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _launchTrainingLink(context, link.url),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.primarySoftBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.cardBorderSoft),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: tokens.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        link.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.primary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (pathway.note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            pathway.note,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textSecondary,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Standalone "where to get certified for this pathway" card: title,
/// subtitle, and a [TrainingLinksList].
class TrainingPathwayCard extends StatelessWidget {
  const TrainingPathwayCard({
    super.key,
    required this.pathway,
    this.subtitle,
  });

  final TrainingPathway pathway;

  /// Defaults to "Verified resources for the {pathway.name} pathway".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where to train',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'Verified resources for the ${pathway.name} pathway',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          const SizedBox(height: 14),
          TrainingLinksList(pathway: pathway),
        ],
      ),
    );
  }
}
