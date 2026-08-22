/// Configuration for Cloudinary direct client uploads.
///
/// You can update [cloudName] and [uploadPreset] with your Cloudinary credentials,
/// or pass them at build/run time with:
/// `--dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name`
/// `--dart-define=CLOUDINARY_UPLOAD_PRESET=your_upload_preset`
class CloudinaryConfig {
  CloudinaryConfig._();

  /// Your Cloudinary Cloud Name (e.g. "my-cloud-name").
  /// Replace this with your actual Cloudinary Cloud Name.
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'YOUR_CLOUDINARY_CLOUD_NAME',
  );

  /// Your Cloudinary Unsigned Upload Preset name (e.g. "skillmatch_uploads" or "ml_default").
  /// Create this in Cloudinary Console: Settings > Upload > Upload presets > Add upload preset (Signing Mode: Unsigned).
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'YOUR_CLOUDINARY_UPLOAD_PRESET',
  );

  /// Optional API key (not required for unsigned uploads).
  static const String apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '',
  );

  /// Root folder prefix for storing assets in Cloudinary.
  static const String folderPrefix = 'skillmatch';

  /// Specific folders for different asset types.
  static const String avatarFolder = '$folderPrefix/avatars';
  static const String resumeFolder = '$folderPrefix/resumes';
  static const String certificationFolder = '$folderPrefix/certifications';

  /// Checks whether Cloudinary credentials have been configured.
  static bool get isConfigured {
    final name = cloudName.trim();
    final preset = uploadPreset.trim();
    return name.isNotEmpty &&
        name != 'YOUR_CLOUDINARY_CLOUD_NAME' &&
        preset.isNotEmpty &&
        preset != 'YOUR_CLOUDINARY_UPLOAD_PRESET';
  }

  /// Cloudinary upload API endpoint.
  static Uri uploadUri({String resourceType = 'auto'}) {
    final cleanCloud = cloudName.trim();
    return Uri.parse(
      'https://api.cloudinary.com/v1_1/$cleanCloud/$resourceType/upload',
    );
  }
}
