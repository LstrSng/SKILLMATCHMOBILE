import 'package:flutter/material.dart';
import 'dart:math';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black87),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, John',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s your career optimization overview.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _StatCard(
                  label: 'Profile',
                  value: '85%',
                  icon: Icons.trending_up,
                  hasProgress: true,
                  subtitle: '',
                ),
                _StatCard(
                  label: 'Matches',
                  value: '12',
                  icon: Icons.business,
                  subtitle: '+2 new today',
                ),
                _StatCard(
                  label: 'Skill Score',
                  value: '742',
                  icon: Icons.flash_on,
                  subtitle: 'Top 10%',
                ),
                _StatCard(
                  label: 'Applied',
                  value: '5',
                  icon: Icons.business_center,
                  subtitle: '2 in interview',
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skill Strength',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your proficiency across key areas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 250,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(200, 200),
                        painter: RadarChartPainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Matches',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _JobMatchCard(
                    title: 'Senior Frontend Engineer',
                    company: 'TechFlow',
                    matchPercentage: 94,
                  ),
                  const SizedBox(height: 12),
                  _JobMatchCard(
                    title: 'Full Stack Developer',
                    company: 'Innovate Inc.',
                    matchPercentage: 88,
                  ),
                  const SizedBox(height: 12),
                  _JobMatchCard(
                    title: 'React Native Developer',
                    company: 'Appify',
                    matchPercentage: 82,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skill Gaps',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Skills to boost your match rate',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Analyze',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SkillGapItem(
                    icon: Icons.code,
                    title: 'GraphQL',
                    priority: 'High Priority',
                    boost: '+15%',
                  ),
                  const SizedBox(height: 12),
                  _SkillGapItem(
                    icon: Icons.cloud,
                    title: 'AWS Lambda',
                    priority: 'Medium Priority',
                    boost: '+8%',
                  ),
                  const SizedBox(height: 12),
                  _SkillGapItem(
                    icon: Icons.storage,
                    title: 'Docker',
                    priority: 'Low Priority',
                    boost: '+5%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Application & skill building progress',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 160,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: BarChartPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String subtitle;
  final bool hasProgress;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.subtitle,
    this.hasProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontSize: 24,
            ),
          ),
          if (hasProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.85,
                minHeight: 6,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2563EB),
                ),
              ),
            ),
          ] else if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobMatchCard extends StatelessWidget {
  final String title;
  final String company;
  final int matchPercentage;

  const _JobMatchCard({
    required this.title,
    required this.company,
    required this.matchPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  company,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5A5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$matchPercentage%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillGapItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String priority;
  final String boost;

  const _SkillGapItem({
    required this.icon,
    required this.title,
    required this.priority,
    required this.boost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEEEE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF8A50), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  priority,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            boost,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    final Paint chartPaint = Paint()
      ..color = const Color(0x4D2563EB)
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final TextPainter textPaint = TextPainter(textDirection: TextDirection.ltr);

    final center = Offset(size.width / 2, size.height / 2);
    const numPoints = 6;
    const labels = [
      'React',
      'Testing',
      'TypeScript',
      'SQL',
      'Design',
      'Node.js',
    ];
    const values = [0.85, 0.75, 0.9, 0.7, 0.65, 0.8];

    // Draw grid circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, (size.width / 2) * (i / 5), gridPaint);
    }

    // Draw grid lines and labels
    for (int i = 0; i < numPoints; i++) {
      final angle = (360 / numPoints) * i * (3.14159 / 180) - (3.14159 / 2);
      final endX = center.dx + (size.width / 2) * 0.9 * cos(angle);
      final endY = center.dy + (size.width / 2) * 0.9 * sin(angle);
      canvas.drawLine(center, Offset(endX, endY), gridPaint);

      // Draw labels
      final labelX = center.dx + (size.width / 2) * 1.15 * cos(angle);
      final labelY = center.dy + (size.width / 2) * 1.15 * sin(angle);

      final textSpan = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      );
      textPaint.text = textSpan;
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(labelX - textPaint.width / 2, labelY - textPaint.height / 2),
      );
    }

    // Draw data polygon
    final path = Path();
    for (int i = 0; i < numPoints; i++) {
      final angle = (360 / numPoints) * i * (3.14159 / 180) - (3.14159 / 2);
      final x = center.dx + (size.width / 2) * 0.8 * values[i] * cos(angle);
      final y = center.dy + (size.width / 2) * 0.8 * values[i] * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, chartPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(RadarChartPainter oldDelegate) => false;
}

class BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint barPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2;

    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    final TextPainter textPaint = TextPainter(textDirection: TextDirection.ltr);

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const values = [4, 3, 7, 5, 8, 2, 4];
    const maxValue = 8.0;

    final barWidth = size.width / 10;
    final chartHeight = size.height * 0.75;
    final padding = size.height * 0.1;

    // Draw grid lines
    for (int i = 0; i <= 8; i += 2) {
      final y = padding + (chartHeight * (1 - (i / 8)));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Draw value labels on Y axis
      final textSpan = TextSpan(
        text: '$i',
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
      );
      textPaint.text = textSpan;
      textPaint.layout();
      textPaint.paint(canvas, Offset(-20, y - 6));
    }

    // Draw bars and labels
    for (int i = 0; i < values.length; i++) {
      final barHeight = (chartHeight * values[i]) / maxValue;
      final x = barWidth * (i + 1);
      final y = padding + chartHeight - barHeight;

      // Draw bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 3, y, barWidth / 1.5, barHeight),
          const Radius.circular(4),
        ),
        barPaint,
      );

      // Draw day labels
      final textSpan = TextSpan(
        text: days[i],
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      );
      textPaint.text = textSpan;
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(x - textPaint.width / 2, padding + chartHeight + 5),
      );
    }
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) => false;
}
