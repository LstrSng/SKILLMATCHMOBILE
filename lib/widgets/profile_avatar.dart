import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// The user's profile photo (network URL or `data:image` URI), or a person
/// icon when there is none or it fails to load.
Widget profileAvatar(
  BuildContext context, {
  required String avatarUrl,
  double size = 80,
  double radius = 12,
  Color? fallbackBg,
  Color? fallbackIconColor,
}) {
  final trimmed = avatarUrl.trim();
  final tokens = context.appColors;
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: fallbackBg ?? tokens.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Center(
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: fallbackIconColor ?? tokens.textFaint,
      ),
    ),
  );

  if (trimmed.isEmpty) return fallback;

  if (trimmed.startsWith('data:image')) {
    final comma = trimmed.indexOf(',');
    if (comma > -1 && comma + 1 < trimmed.length) {
      try {
        final bytes = base64Decode(trimmed.substring(comma + 1));
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.network(
      trimmed,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    ),
  );
}
