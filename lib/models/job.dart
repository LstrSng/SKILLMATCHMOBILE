import 'package:flutter/material.dart';

class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String salary;
  final String jobType;
  final int matchPercentage;
  final String initial;
  final Color initialColor;
  final List<String> matchedSkills;
  final List<String> unmatchedSkills;
  final String description;
  final String postedDate;

  Job({
    this.id = '',
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.jobType,
    required this.matchPercentage,
    required this.initial,
    required this.initialColor,
    required this.matchedSkills,
    required this.unmatchedSkills,
    required this.description,
    required this.postedDate,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final company = (json['company'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? 'Untitled role';
    final id = (json['id'] as Object?)?.toString().trim() ??
        (json['_id'] as Object?)?.toString().trim() ??
        '';
    final posted = (json['postedDate'] as String?)?.trim() ?? '';
    return Job(
      id: id,
      title: title,
      company: company,
      location: (json['location'] as String?)?.trim() ?? '',
      salary: (json['salary'] as String?)?.trim() ?? '',
      jobType: (json['jobType'] as String?)?.trim() ?? '',
      matchPercentage: _parseMatchPercent(json['matchPercentage']),
      initial: _initialFromCompany(company),
      initialColor: _brandColorForKey(company.isNotEmpty ? company : title),
      matchedSkills: _stringList(json['matchedSkills']),
      unmatchedSkills: _stringList(json['unmatchedSkills']),
      description: (json['description'] as String?)?.trim() ?? '',
      postedDate: posted.isNotEmpty ? posted : 'Recently posted',
    );
  }

  static int _parseMatchPercent(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString()).toList();
  }

  static String _initialFromCompany(String c) {
    final t = c.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  static const List<Color> _palette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF059669),
    Color(0xFF0891B2),
    Color(0xFFD97706),
  ];

  static Color _brandColorForKey(String key) {
    if (key.isEmpty) return _palette[0];
    var h = 0;
    for (var i = 0; i < key.length; i++) {
      h = key.codeUnitAt(i) + ((h << 5) - h);
    }
    return _palette[h.abs() % _palette.length];
  }

  Job copyWith({
    int? matchPercentage,
    List<String>? matchedSkills,
    List<String>? unmatchedSkills,
  }) {
    return Job(
      id: id,
      title: title,
      company: company,
      location: location,
      salary: salary,
      jobType: jobType,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      initial: initial,
      initialColor: initialColor,
      matchedSkills: matchedSkills ?? this.matchedSkills,
      unmatchedSkills: unmatchedSkills ?? this.unmatchedSkills,
      description: description,
      postedDate: postedDate,
    );
  }
}
