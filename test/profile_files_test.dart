import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/pages/profile_page.dart';

void main() {
  group('Profile Files & Certifications Tests', () {
    test('readProfileResume returns null when resume is missing or empty', () {
      expect(readProfileResume({}), isNull);
      expect(readProfileResume({'resume': null}), isNull);
      expect(readProfileResume({'resume': {}}), isNull);
      expect(readProfileResume({'resume': {'name': '', 'url': '', 'data': ''}}), isNull);
    });

    test('readProfileResume returns valid map when resume is present', () {
      final data = {
        'resume': {
          'name': 'my_resume.pdf',
          'url': 'https://cloudinary.com/resumes/my_resume.pdf',
          'mimeType': 'application/pdf',
          'size': 1024,
          'updatedAt': '2026-09-01T00:00:00.000Z',
        }
      };
      final parsed = readProfileResume(data);
      expect(parsed, isNotNull);
      expect(parsed!['name'], 'my_resume.pdf');
      expect(parsed['url'], 'https://cloudinary.com/resumes/my_resume.pdf');
      expect(parsed['mimeType'], 'application/pdf');
      expect(parsed['size'], 1024);
      expect(parsed['updatedAt'], '2026-09-01T00:00:00.000Z');
    });

    test('readProfileCertifications supports backwards compatibility with single certification', () {
      final legacyData = {
        'certification': {
          'name': 'AWS_Solutions_Architect.pdf',
          'url': 'https://cloudinary.com/cert/aws.pdf',
          'mimeType': 'application/pdf',
          'size': 2048,
        }
      };

      final certs = readProfileCertifications(legacyData);
      expect(certs.length, equals(1));
      expect(certs.first['name'], equals('AWS_Solutions_Architect.pdf'));
      expect(certs.first['url'], equals('https://cloudinary.com/cert/aws.pdf'));
      expect(certs.first['size'], equals(2048));
    });

    test('readProfileCertifications supports multiple certifications', () {
      final multiData = {
        'certifications': [
          {
            'id': 'cert_1',
            'name': 'AWS_Certified.pdf',
            'url': 'https://cloudinary.com/cert/aws.pdf',
            'size': 1500,
          },
          {
            'id': 'cert_2',
            'name': 'Google_Cloud_Architect.png',
            'url': 'https://cloudinary.com/cert/gcp.png',
            'size': 2500,
          },
          {
            'id': 'cert_3',
            'name': 'Scrum_Master.docx',
            'url': 'https://cloudinary.com/cert/scrum.docx',
            'size': 3500,
          },
        ]
      };

      final certs = readProfileCertifications(multiData);
      expect(certs.length, equals(3));
      expect(certs[0]['name'], equals('AWS_Certified.pdf'));
      expect(certs[1]['name'], equals('Google_Cloud_Architect.png'));
      expect(certs[2]['name'], equals('Scrum_Master.docx'));
    });

    test('readProfileCertifications ignores corrupted or empty items', () {
      final mixedData = {
        'certifications': [
          null,
          'not-a-map',
          {'name': '', 'url': '', 'data': ''},
          {
            'id': 'cert_valid',
            'name': 'Valid_Cert.pdf',
            'url': 'https://example.com/cert.pdf',
          },
        ]
      };

      final certs = readProfileCertifications(mixedData);
      expect(certs.length, equals(1));
      expect(certs.first['name'], equals('Valid_Cert.pdf'));
    });

    test('parseProfileFileItem generates fallbacks when id or name is blank', () {
      final item = parseProfileFileItem(
        {'publicId': 'pub_123', 'url': 'https://example.com/file.pdf'},
        fallbackName: 'Default Certificate',
      );

      expect(item, isNotNull);
      expect(item!['id'], equals('pub_123'));
      expect(item['name'], equals('Default Certificate'));
      expect(item['url'], equals('https://example.com/file.pdf'));
    });
  });
}
