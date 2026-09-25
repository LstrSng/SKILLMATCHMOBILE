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
///
/// When [onToggleCompleted] is set, each link gets a "mark as completed"
/// button, and links whose label is in [completedKeys] show as completed.
class TrainingLinksList extends StatelessWidget {
  const TrainingLinksList({
    super.key,
    required this.pathway,
    this.completedKeys = const {},
    this.onToggleCompleted,
  });

  final TrainingPathway pathway;
  final Set<String> completedKeys;
  final void Function(TrainingResource link, bool completed)?
  onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...pathway.links.map(
          (link) {
            final isFree = (link.isFree == true) || link.label.toLowerCase().contains('free');
            final provider = link.provider;
            final type = link.type;
            final isTesda = (provider?.toLowerCase().contains('tesda') ?? false) ||
                (type?.toLowerCase().contains('tesda') ?? false) ||
                link.label.toLowerCase().contains('tesda');
            final isDone = completedKeys.contains(
              link.label.trim().toLowerCase(),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _launchTrainingLink(context, link.url),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDone ? tokens.successBg : tokens.primarySoftBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone
                          ? tokens.success.withValues(alpha: 0.5)
                          : tokens.cardBorderSoft,
                    ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDone ? tokens.success : tokens.primary,
                                height: 1.3,
                              ),
                            ),
                            if (isDone) ...[
                              const SizedBox(height: 3),
                              Text(
                                '✓ Completed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.success,
                                ),
                              ),
                            ],
                            if (provider != null || type != null) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (provider != null)
                                    Flexible(
                                      child: Text(
                                        provider,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: tokens.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (provider != null && type != null)
                                    Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  if (type != null)
                                    Flexible(
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: tokens.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isTesda) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: tokens.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'TESDA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tokens.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                      if (isFree) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.successBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: tokens.success.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tokens.success,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      if (onToggleCompleted != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: isDone
                              ? 'Mark as not completed'
                              : 'Mark as completed',
                          icon: Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isDone ? tokens.success : tokens.textFaint,
                            size: 22,
                          ),
                          onPressed: () => onToggleCompleted!(link, !isDone),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
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
    this.completedKeys = const {},
    this.onToggleCompleted,
  });

  final TrainingPathway pathway;

  /// Defaults to "Verified resources for the {pathway.name} pathway".
  final String? subtitle;

  final Set<String> completedKeys;
  final void Function(TrainingResource link, bool completed)?
  onToggleCompleted;

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
          if (onToggleCompleted != null) ...[
            Text(
              'Passed or finished one? Tap ○ to mark it as completed.',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
          TrainingLinksList(
            pathway: pathway,
            completedKeys: completedKeys,
            onToggleCompleted: onToggleCompleted,
          ),
        ],
      ),
    );
  }
}
