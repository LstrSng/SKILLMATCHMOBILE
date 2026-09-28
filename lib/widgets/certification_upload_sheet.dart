import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cloudinary_service.dart';
import '../services/pathway_certification.dart';
import 'package:skillmatch/theme/app_colors.dart';

const _kMaxCertBytes = 5 * 1024 * 1024;

/// Optional first step when completing an upskilling step: asks for a
/// certificate PDF for [skill]. Returns null if dismissed, a record with a
/// null draft on Skip (or Continue without a file), or the picked draft.
/// [suggestedTitle] and [suggestedIssuer] prefill the fields.
Future<({CertificationDraft? draft})?> showCertificationUploadSheet(
  BuildContext context, {
  required String skill,
  String? suggestedTitle,
  String? suggestedIssuer,
}) {
  return showModalBottomSheet<({CertificationDraft? draft})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CertificationUploadSheet(
      skill: skill,
      suggestedTitle: suggestedTitle,
      suggestedIssuer: suggestedIssuer,
    ),
  );
}

class _CertificationUploadSheet extends StatefulWidget {
  const _CertificationUploadSheet({
    required this.skill,
    required this.suggestedTitle,
    required this.suggestedIssuer,
  });

  final String skill;
  final String? suggestedTitle;
  final String? suggestedIssuer;

  @override
  State<_CertificationUploadSheet> createState() =>
      _CertificationUploadSheetState();
}

class _CertificationUploadSheetState extends State<_CertificationUploadSheet> {
  late final _title = TextEditingController(text: widget.suggestedTitle ?? '');
  late final _issuer = TextEditingController(
    text: widget.suggestedIssuer ?? '',
  );
  PlatformFile? _file;
  String? _fileError;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _issuer.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      if ((file.extension ?? '').toLowerCase() != 'pdf') {
        _fileError = 'Choose a PDF file.';
      } else if (file.bytes == null) {
        _fileError = "Couldn't read that file. Try another.";
      } else if (file.size > _kMaxCertBytes) {
        _fileError = 'The PDF must be 5 MB or smaller.';
      } else {
        _file = file;
        _fileError = null;
      }
    });
  }

  void _continue() {
    final file = _file;
    if (file == null) {
      Navigator.of(context).pop((draft: null));
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter the certificate name.');
      return;
    }
    final issuer = _issuer.text.trim();
    Navigator.of(context).pop((
      draft: CertificationDraft(
        fileName: file.name,
        bytes: file.bytes!,
        title: title,
        issuer: issuer.isEmpty ? null : issuer,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final file = _file;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.cardBorderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.primarySoftBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: tokens.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Have a certificate for ${widget.skill}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Upload it and it'll be added to your profile. You can skip this.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
            const SizedBox(height: 18),
            if (file == null)
              _UploadBox(onTap: _pick)
            else
              _PickedFile(
                file: file,
                onRemove: () => setState(() => _file = null),
              ),
            if (_fileError != null) ...[
              const SizedBox(height: 6),
              Text(
                _fileError!,
                style: TextStyle(fontSize: 12.5, color: tokens.danger),
              ),
            ],
            if (file != null) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Certificate name',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _issuer,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Issued by (optional)',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop((draft: null)),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Material(
      color: tokens.primarySoftBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(Icons.upload_file_rounded, color: tokens.primary),
              const SizedBox(height: 4),
              Text(
                'Upload PDF',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Max 5 MB',
                style: TextStyle(fontSize: 11.5, color: tokens.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedFile extends StatelessWidget {
  const _PickedFile({required this.file, required this.onRemove});

  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorderSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: tokens.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  CloudinaryService.formatFileSize(file.size),
                  style: TextStyle(fontSize: 12, color: tokens.textFaint),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove file',
            icon: Icon(Icons.close_rounded, color: tokens.textFaint),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
