import 'package:flutter/material.dart';
import 'job_detail_page.dart';
import 'settings_page.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _searchController = TextEditingController();

  final List<Job> jobs = [
    Job(
      title: 'Senior Frontend Engineer',
      company: 'TechFlow',
      location: 'San Francisco, CA (Remote)',
      salary: '\$140k-\$180k',
      jobType: 'Full-time',
      matchPercentage: 94,
      initial: 'T',
      initialColor: const Color(0xFF2563EB),
      matchedSkills: ['React', 'TypeScript', 'Tailwind', 'Next.js'],
      unmatchedSkills: [],
      description:
          'We are looking for a Senior Frontend Engineer to join our team. You will be responsible for building high-quality, scalable web applications using React and TypeScript. You will work closely with our product and design teams to craft delightful user experiences. This role involves leading frontend architecture decisions, mentoring junior developers, and collaborating with backend teams to deliver seamless full-stack solutions.',
    ),
    Job(
      title: 'Full Stack Developer',
      company: 'Innovate Inc.',
      location: 'New York, NY',
      salary: '\$120k-\$160k',
      jobType: 'Hybrid',
      matchPercentage: 88,
      initial: 'I',
      initialColor: const Color(0xFF9333EA),
      matchedSkills: ['React', 'Node.js'],
      unmatchedSkills: [],
      description:
          'Join our dynamic team as a Full Stack Developer where you\'ll work on both frontend and backend technologies. You\'ll build responsive web applications using React for the frontend and Node.js for the backend. This role offers the opportunity to work on diverse projects, from customer-facing applications to internal tools, while collaborating with cross-functional teams including product managers, designers, and other developers.',
    ),
    Job(
      title: 'Product Designer',
      company: 'Creative Studio',
      location: 'Austin, TX',
      salary: '\$110k-\$150k',
      jobType: 'Full-time',
      matchPercentage: 76,
      initial: 'C',
      initialColor: const Color(0xFFEC4899),
      matchedSkills: ['Figma', 'UI/UX', 'Prototyping'],
      unmatchedSkills: ['HTML/CSS'],
      description:
          'We\'re seeking a talented Product Designer to create intuitive and beautiful user experiences. You\'ll work closely with our product and engineering teams to design user interfaces that solve real problems. Using Figma and other design tools, you\'ll create wireframes, prototypes, and high-fidelity designs. This role involves user research, usability testing, and collaborating with developers to ensure your designs are implemented effectively.',
    ),
    Job(
      title: 'Backend Engineer',
      company: 'DataSystems',
      location: 'Remote',
      salary: '\$130k-\$170k',
      jobType: 'Contract',
      matchPercentage: 65,
      initial: 'D',
      initialColor: const Color(0xFF22C55E),
      matchedSkills: ['Python', 'Django'],
      unmatchedSkills: ['Docker', 'Kubernetes'],
      description:
          'We need a skilled Backend Engineer to build robust and scalable server-side applications. You\'ll work with Python and Django to develop RESTful APIs, manage databases, and ensure high performance and security. This contract position offers flexibility to work remotely while contributing to mission-critical systems. You\'ll collaborate with frontend developers and DevOps teams to deliver complete solutions.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Find Jobs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: const Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Top matches for you',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search roles, skills, companies...',
                      hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, color: Colors.black87),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Job Listings
            Column(children: jobs.map((job) => _JobCard(job: job)).toList()),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailPage(
              title: job.title,
              company: job.company,
              location: job.location,
              salary: job.salary,
              jobType: job.jobType,
              postedDate: '2 days ago',
              matchPercentage: job.matchPercentage,
              description: job.description,
              matchedSkills: job.matchedSkills,
              unmatchedSkills: job.unmatchedSkills,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and match percentage
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: job.initialColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      job.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF0EA5A5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${job.matchPercentage}%',
                    style: const TextStyle(
                      color: Color(0xFF0EA5A5),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  job.location,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Salary and Job Type
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: const Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  job.salary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  job.jobType == 'Full-time'
                      ? Icons.schedule
                      : Icons.location_on,
                  color: const Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  job.jobType,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Skill Match
            Text(
              'SKILL MATCH',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Skills Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...job.matchedSkills.map(
                  (skill) => _SkillChip(skill: skill, matched: true),
                ),
                ...job.unmatchedSkills.map(
                  (skill) => _SkillChip(skill: skill, matched: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final bool matched;

  const _SkillChip({required this.skill, required this.matched});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        border: Border.all(
          color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            skill,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: matched
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class Job {
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

  Job({
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
  });
}
