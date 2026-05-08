class CloudinaryConfig {
  CloudinaryConfig._();

  // Thay bằng Cloud name của tài khoản Cloudinary
  static const String cloudName = 'dmlf3lcd0';

  // Thay bằng unsigned upload preset của bạn
  static const String uploadPreset = 'smart_expense_unsigned';

  static String get uploadUrl {
    return 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  }
}
