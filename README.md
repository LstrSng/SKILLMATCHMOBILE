# SkillMatch+

SkillMatch+ is a Flutter mobile app for IT job seekers. It compares your
skills and skill levels with real job postings, shows how qualified you are
for each job, and gives you a prioritized upskilling pathway with free
certifications to close the gaps.

Skill requirements come from the **PSF-SDS** (Philippine Skills Framework –
Software Development Services) dataset, so matching uses the same
competency levels as the industry framework, not only skill names.

## Features

### Account and sign-in
- Registration with input validation (letters-only names, email, `09…`
  phone number, strong password), checked on both the app and the backend
- Email OTP for registration, sign-in and password reset
- Remembered sessions on trusted devices

### Skill onboarding and profile
- New accounts pick their skills and rate each one from 1 to 10 before
  reaching the home screen
- Skills grouped into **Tech Stack**, **Functional** and **Enabling**, each
  shown with its PSF-SDS level
- Profile with headline, contact details, education, experience, avatar,
  resume and certification uploads (PDF, DOC, DOCX or image)
- Profile strength meter with tips on what to add next
- Light and dark mode

### Jobs and matching
- Job listings with a competency-weighted match score for your profile
- Job details compare each required skill with your level: meets, below
  level, or missing
- Job qualification card: your qualified percentage and what to improve
- Short coding question before applying to developer jobs
- Saved (bookmarked) jobs and company details
- Matches update right away when your skills change

### Prescriptive recommendations and upskilling
- Smart match recommendation ranks upskilling actions by qualification
  gain, how many other posted jobs need the skill, role relevance and cost
- **Upskilling pathway** per job: only the skills you still lack, highest
  priority first, with free certifications that fit the required level
- **Completing a step**:
  1. Optional certificate upload (PDF, up to 5 MB), which you can skip
  2. Pick your level in the skill on the 1–10 scale (1 for a new skill,
     your current rating otherwise)
  3. The skill is added to your profile at that level. The certificate is
     added to your certifications with its name, issuer and a
     "From upskilling pathway" tag, and your qualification is recomputed.
- Pathways tab: certifications for skill gaps across posted jobs, with
  free / free-to-learn / paid badges and progress tracking

### Assessments and applications
- Skill assessments with saved results
- Application tracking with a status timeline
- In-app notifications for application updates and new job matches

## Competency levels

Applicants rate skills from 1 to 10. The app maps a rating to the level a
job asks for:

| Rating | PSF-SDS functional level | Enabling level |
|--------|--------------------------|----------------|
| 1      | Level 1                  | Basic          |
| 2–3    | Level 2                  | Basic          |
| 4–5    | Level 3                  | Intermediate   |
| 6      | Level 4                  | Intermediate   |
| 7      | Level 5                  | Intermediate   |
| 8      | Level 5                  | Advanced       |
| 9–10   | Level 6                  | Advanced       |

A skill **meets** a requirement when the rating reaches the level's
minimum. The mapping lives in `lib/services/competency.dart`.

## Tech stack

| Part      | Technology                                             |
|-----------|--------------------------------------------------------|
| Mobile    | Flutter (Dart SDK ^3.10.3), Android and iOS            |
| Backend   | Node.js, Express, MongoDB (Mongoose)                   |
| Email     | Resend (OTP emails)                                    |
| Files     | Cloudinary (avatars, resumes, certifications)          |
| Hosting   | Render                                                 |

## Project structure

```
lib/
  config/     API base URL and Cloudinary settings
  models/     Data models (training pathways, assessments, job roles)
  pages/      Screens (jobs, job detail, pathways, profile, …)
  services/   API clients, matching, competency and recommendation logic
  theme/      Colors and light/dark themes
  widgets/    Shared widgets (cards, sheets, toasts, …)
assets/data/
  psf_sds_data.json           PSF-SDS roles, skills and levels
  psf_assessments.json        Skill assessment questions
  career_pathway_links.json   Certification and training links
backend/
  server.js   Express API
  models/     Mongoose models (users, jobs, applications, OTP, …)
  utils/      Mailer, OTP, trusted devices, skill grouping
  scripts/    One-time migrations
test/         Flutter unit and widget tests
```

## Getting started

### Mobile app

```bash
flutter pub get
flutter run
```

By default the app uses the deployed backend. To point it at another
backend, such as one running locally, pass `--dart-define=API_BASE_URL=<url>`.
File upload settings are also passed with `--dart-define`. Ask the project
maintainer for the values.

### Backend

```bash
cd backend
npm install
npm start
```

Use `npm run dev` to restart on changes. The backend needs a `backend/.env`
file with the database, email and security settings. Ask the project
maintainer for it, and never commit it to the repository.

To convert skills saved in an older format, run `npm run migrate:skills`
once. See `backend/README.txt` for troubleshooting local connections.

## Running for a demo or release

```bash
flutter run --release
```

Release mode is faster, has no debug banner, and keeps working after the
cable is unplugged. It has no hot reload, and it needs a physical iPhone
on iOS (the simulator only runs debug mode).

To build an installable Android file:

```bash
flutter build apk --release
```

The APK is saved to `build/app/outputs/flutter-apk/app-release.apk`.
Open the app a few minutes before a demo so the backend is awake and
responding.

## Tests

```bash
flutter test
flutter analyze
```
