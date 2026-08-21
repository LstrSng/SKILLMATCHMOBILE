import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/job_role_skills.dart';
import '../models/training_pathway.dart';
import '../services/job_roles_data.dart';
import '../services/pathway_links_data.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/training_pathway_card.dart';
import 'learning_page.dart';

const _kBlue = Color(0xFF2563EB);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kLockedFill = Color(0xFFF3F4F6);

const _kCertAllowedExtensions = {'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'};
const _kCertMaxBytes = 5 * 1024 * 1024;

String _certificateMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

Future<Uint8List?> _certificateBytesFromPick(PlatformFile file) async {
  if (file.bytes != null) return file.bytes;
  final stream = file.readStream;
  if (stream == null) return null;
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

class PathwayPage extends StatefulWidget {
  const PathwayPage({super.key});

  @override
  State<PathwayPage> createState() => _PathwayPageState();
}

class _PathwayPageState extends State<PathwayPage> {
  bool _loading = true;
  String? _error;
  List<JobRoleSkills> _roles = [];
  JobRoleSkills? _selected;
  Set<String> _mySkillKeys = {};
  TrainingPathway? _trainingPathway;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<String> _readMySkills() {
    final v = SessionStore.user?['skills'];
    if (v is List) {
      return v
          .map((e) => e.toString().trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    return {};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roles = await loadJobRoles();
      if (!mounted) return;
      JobRoleSkills? defaultRole;
      for (final r in roles) {
        if (r.title.toLowerCase() == 'full stack developer') {
          defaultRole = r;
          break;
        }
      }
      defaultRole ??= roles.isNotEmpty ? roles.first : null;
      setState(() {
        _roles = roles;
        _selected = defaultRole;
        _mySkillKeys = _readMySkills();
        _loading = false;
      });
      _loadTrainingPathway(defaultRole?.title);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickRole() async {
    final picked = await showModalBottomSheet<JobRoleSkills>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _RolePickerSheet(roles: _roles, initial: _selected),
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
      _loadTrainingPathway(picked.title);
    }
  }

  Future<void> _loadTrainingPathway(String? roleTitle) async {
    if (roleTitle == null) {
      setState(() => _trainingPathway = null);
      return;
    }
    final pathway = await trainingPathwayForRole(roleTitle);
    if (!mounted) return;
    setState(() => _trainingPathway = pathway);
  }

  Future<void> _addSkillToProfile(
    String skill, {
    required PlatformFile certificateFile,
  }) async {
    final bytes = await _certificateBytesFromPick(certificateFile);
    if (bytes == null) {
      throw Exception('Could not read the selected file.');
    }

    final rawSkills = SessionStore.user?['skills'];
    final current = rawSkills is List
        ? rawSkills.map((e) => e.toString()).toList()
        : <String>[];
    if (!current.any((s) => s.trim().toLowerCase() == skill.toLowerCase())) {
      current.add(skill);
    }

    final rawProfile = SessionStore.user?['profile'];
    final profile = rawProfile is Map
        ? rawProfile.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    final rawCerts = profile['skillCertificates'];
    final certs = rawCerts is Map
        ? rawCerts.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    certs[skill.trim().toLowerCase()] = {
      'skill': skill,
      'name': certificateFile.name,
      'mimeType': _certificateMimeType(certificateFile.name),
      'data': base64Encode(bytes),
      'uploadedAt': DateTime.now().toUtc().toIso8601String(),
    };
    profile['skillCertificates'] = certs;

    await updateMyProfile({'skills': current, 'profile': profile});
    if (!mounted) return;
    setState(() => _mySkillKeys = _readMySkills());
    showAppToast(
      context,
      'Added "$skill" with your certificate.',
      type: AppToastType.success,
    );
  }

  void _onNodeTap(String skill, bool mastered) {
    if (mastered) {
      showAppToast(
        context,
        'You already have "$skill". Nice work!',
        type: AppToastType.success,
      );
      return;
    }
    if (SessionStore.user == null) {
      showAppToast(
        context,
        'Sign in to track your skill progress.',
        type: AppToastType.info,
      );
      return;
    }
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddSkillSheet(
        skill: skill,
        onSubmit: (file) => _addSkillToProfile(skill, certificateFile: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _selected == null
          ? const Center(child: Text('No career pathways available yet.'))
          : _buildContent(context, _selected!),
    );
  }

  Widget _buildContent(BuildContext context, JobRoleSkills role) {
    final mastered = role.skills
        .where((s) => _mySkillKeys.contains(s.toLowerCase()))
        .toList();
    final remaining = role.skills
        .where((s) => !_mySkillKeys.contains(s.toLowerCase()))
        .toList();
    final ordered = [...mastered, ...remaining];
    final total = role.skills.length;
    final progress = total == 0 ? 0.0 : mastered.length / total;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Career Pathway',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Follow the skill path to your next role',
            style: TextStyle(fontSize: 16, color: _kGray),
          ),
          const SizedBox(height: 20),

          // Role selector
          AppCard(
            onTap: _pickRole,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.route, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target role',
                        style: TextStyle(fontSize: 12, color: _kGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more, color: _kGray),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your progress',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${mastered.length}/$total skills',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: _kBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
                  ),
                ),
                if (role.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    role.description,
                    style: const TextStyle(fontSize: 13, color: _kGray, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LearningPage(initialRoleTitle: role.title),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.show_chart, size: 16, color: _kBlue),
                    label: const Text(
                      'View full skill gap analysis',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Dot pathway
          if (ordered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No skills listed for this role.'),
            )
          else
            _PathwayTrack(
              skills: ordered,
              masteredCount: mastered.length,
              onTapNode: (skill, isMastered) => _onNodeTap(skill, isMastered),
            ),

          const SizedBox(height: 8),

          if (role.certifications.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommended certifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Credentials that reinforce this pathway',
                    style: TextStyle(fontSize: 13, color: _kGray),
                  ),
                  const SizedBox(height: 12),
                  ...role.certifications.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified, size: 18, color: _kBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c,
                              style: const TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (_trainingPathway != null) ...[
            TrainingPathwayCard(pathway: _trainingPathway!),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

enum _NodeState { mastered, current, locked }

class _PathwayTrack extends StatelessWidget {
  final List<String> skills;
  final int masteredCount;
  final void Function(String skill, bool mastered) onTapNode;

  const _PathwayTrack({
    required this.skills,
    required this.masteredCount,
    required this.onTapNode,
  });

  static const double _dotSize = 52;
  static const double _rowHeight = 112;
  static const List<double> _xFractions = [0.5, 0.78, 0.5, 0.22];

  double _xFor(int index, double width) {
    final margin = _dotSize; // keep dots clear of the screen edges
    final usable = width - margin * 2;
    final fraction = _xFractions[index % _xFractions.length];
    return margin + usable * fraction;
  }

  double _yFor(int index) => _dotSize / 2 + index * _rowHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final points = List.generate(
          skills.length,
          (i) => Offset(_xFor(i, width), _yFor(i)),
        );
        final height = _yFor(skills.length - 1) + _dotSize / 2 + 16;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _PathPainter(points: points, masteredCount: masteredCount),
              ),
              for (var i = 0; i < skills.length; i++)
                Positioned(
                  left: points[i].dx - 50,
                  top: points[i].dy - _dotSize / 2,
                  width: 100,
                  child: _PathwayNode(
                    skill: skills[i],
                    number: i + 1,
                    state: i < masteredCount
                        ? _NodeState.mastered
                        : i == masteredCount
                        ? _NodeState.current
                        : _NodeState.locked,
                    onTap: () => onTapNode(skills[i], i < masteredCount),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final int masteredCount;

  _PathPainter({required this.points, required this.masteredCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final donePaint = Paint()
      ..color = _kBlue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final todoPaint = Paint()
      ..color = _kBorder
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final path = Path()..moveTo(p0.dx, p0.dy);
      final midY = (p0.dy + p1.dy) / 2;
      path.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
      final isDone = i < masteredCount - 1;
      canvas.drawPath(path, isDone ? donePaint : todoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.masteredCount != masteredCount ||
        oldDelegate.points.length != points.length;
  }
}

class _PathwayNode extends StatelessWidget {
  final String skill;
  final int number;
  final _NodeState state;
  final VoidCallback onTap;

  const _PathwayNode({
    required this.skill,
    required this.number,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final Widget inner;
    final Color labelColor;
    final FontWeight labelWeight;

    switch (state) {
      case _NodeState.mastered:
        fill = _kBlue;
        border = _kBlue;
        inner = const Icon(Icons.check, color: Colors.white, size: 24);
        labelColor = Colors.black;
        labelWeight = FontWeight.w600;
        break;
      case _NodeState.current:
        fill = Colors.white;
        border = _kBlue;
        inner = Text(
          '$number',
          style: const TextStyle(
            color: _kBlue,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        );
        labelColor = _kBlue;
        labelWeight = FontWeight.w700;
        break;
      case _NodeState.locked:
        fill = _kLockedFill;
        border = _kBorder;
        inner = Text(
          '$number',
          style: const TextStyle(
            color: _kGray,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        );
        labelColor = _kGray;
        labelWeight = FontWeight.w500;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: border,
                width: state == _NodeState.current ? 3 : 2,
              ),
              boxShadow: state == _NodeState.mastered
                  ? [
                      BoxShadow(
                        color: _kBlue.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(child: inner),
          ),
          const SizedBox(height: 6),
          Text(
            skill,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: labelColor,
              fontWeight: labelWeight,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePickerSheet extends StatefulWidget {
  final List<JobRoleSkills> roles;
  final JobRoleSkills? initial;

  const _RolePickerSheet({required this.roles, required this.initial});

  @override
  State<_RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends State<_RolePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.roles
        : widget.roles.where((r) => r.title.toLowerCase().contains(q)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a target role',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search roles (e.g. Full Stack Developer)',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matching roles.'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: _kBorder),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          final selected = widget.initial?.title == r.title;
                          return ListTile(
                            title: Text(
                              r.title,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? _kBlue : Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              '${r.skills.length} skills',
                              style: const TextStyle(fontSize: 12, color: _kGray),
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle, color: _kBlue)
                                : null,
                            onTap: () => Navigator.pop(context, r),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddSkillSheet extends StatefulWidget {
  final String skill;
  final Future<void> Function(PlatformFile certificateFile) onSubmit;

  const _AddSkillSheet({required this.skill, required this.onSubmit});

  @override
  State<_AddSkillSheet> createState() => _AddSkillSheetState();
}

class _AddSkillSheetState extends State<_AddSkillSheet> {
  PlatformFile? _picked;
  bool _saving = false;
  String? _error;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kCertAllowedExtensions.toList(),
      withData: true,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final ext = (file.extension ?? '').toLowerCase();
    if (!_kCertAllowedExtensions.contains(ext)) {
      setState(
        () => _error = 'Please choose a PDF, DOC, DOCX, JPG, or PNG file.',
      );
      return;
    }
    if (file.size > _kCertMaxBytes) {
      setState(() => _error = 'Certificate must be 5MB or smaller.');
      return;
    }
    setState(() => _picked = file);
  }

  Future<void> _submit() async {
    if (_picked == null) {
      setState(() => _error = 'Upload a certificate to add this skill.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_picked!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add "${widget.skill}"',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload a certificate to prove this skill before adding it.',
            style: TextStyle(fontSize: 13, color: _kGray),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _saving ? null : _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF9FAFB),
              ),
              child: _picked == null
                  ? const Column(
                      children: [
                        Icon(Icons.upload_file, color: _kGray, size: 28),
                        SizedBox(height: 8),
                        Text(
                          'Tap to upload certificate (required)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'PDF, DOC, DOCX, JPG, or PNG · up to 5MB',
                          style: TextStyle(fontSize: 11, color: _kGray),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.description, color: _kBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _picked!.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _picked = null),
                        ),
                      ],
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add skill with certificate'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
