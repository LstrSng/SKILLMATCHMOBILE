import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/training_pathway.dart';
import '../theme/app_colors.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...pathway.links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _launchTrainingLink(context, link.url),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoftBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        link.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
        if (pathway.note.isNotEmpty)
          Text(
            pathway.note,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}

/// Standalone "where to get certified for this pathway" card: title,
/// subtitle, and a [TrainingLinksList]. Used by the Pathway tab, where
/// it isn't nested inside another card.
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where to train',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'Verified resources for the ${pathway.name} pathway',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TrainingLinksList(pathway: pathway),
        ],
      ),
    );
  }
}
