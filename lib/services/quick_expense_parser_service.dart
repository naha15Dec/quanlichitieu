class QuickExpenseParseResult {
  final String title;
  final double? amount;
  final String type;
  final String category;
  final bool hasAmount;
  final bool hasTitle;

  const QuickExpenseParseResult({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.hasAmount,
    required this.hasTitle,
  });

  bool get isValid => hasTitle && hasAmount && amount != null && amount! > 0;
}

class QuickExpenseParserService {
  QuickExpenseParseResult parse(String input) {
    final original = input.trim();

    if (original.isEmpty) {
      return const QuickExpenseParseResult(
        title: '',
        amount: null,
        type: 'expense',
        category: 'Ăn uống',
        hasAmount: false,
        hasTitle: false,
      );
    }

    final amountInfo = _extractAmount(original);
    final amount = amountInfo?.amount;
    final sign = amountInfo?.sign;

    String title = original;

    if (amountInfo != null) {
      title = title.replaceFirst(amountInfo.rawText, ' ');
    }

    title = _cleanTitle(title);

    final normalizedInput = _normalize(original);
    final normalizedTitle = _normalize(title);

    final type = _detectType(normalizedInput: normalizedInput, sign: sign);

    final category = _detectCategory(
      normalizedInput: normalizedInput,
      normalizedTitle: normalizedTitle,
      type: type,
    );

    return QuickExpenseParseResult(
      title: title,
      amount: amount,
      type: type,
      category: category,
      hasAmount: amount != null && amount > 0,
      hasTitle: title.trim().isNotEmpty,
    );
  }

  _AmountInfo? _extractAmount(String input) {
    final pattern = RegExp(
      r'([+-])?\s*((?:\d{1,3}(?:[.,]\d{3})+)|(?:\d+(?:[.,]\d+)?))\s*(triệu|trieu|tr|m|nghìn|nghin|ngàn|ngan|k|đ|d|vnd)?',
      caseSensitive: false,
      unicode: true,
    );

    final matches = pattern.allMatches(input).toList();

    if (matches.isEmpty) return null;

    _AmountInfo? best;

    for (final match in matches) {
      final raw = match.group(0)?.trim() ?? '';
      final sign = match.group(1);
      final numberPart = match.group(2)?.trim() ?? '';
      final unit = match.group(3)?.trim().toLowerCase();

      if (raw.isEmpty || numberPart.isEmpty) continue;

      final amount = _parseAmountValue(numberPart, unit);

      if (amount == null || amount <= 0) continue;

      if (amount < 1000) continue;

      final current = _AmountInfo(rawText: raw, amount: amount, sign: sign);

      best ??= current;

      if (_scoreAmount(raw, unit) > _scoreAmount(best.rawText, null)) {
        best = current;
      }
    }

    return best;
  }

  double? _parseAmountValue(String numberPart, String? unit) {
    final normalizedUnit = unit == null ? '' : _normalize(unit);

    String cleaned = numberPart.trim();

    double? value;

    final hasMoneyGrouping = RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(cleaned);

    if (hasMoneyGrouping) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '');
      value = double.tryParse(cleaned);
    } else {
      cleaned = cleaned.replaceAll(',', '.');
      value = double.tryParse(cleaned);
    }

    if (value == null) return null;

    if (normalizedUnit == 'trieu' ||
        normalizedUnit == 'tr' ||
        normalizedUnit == 'm') {
      return value * 1000000;
    }

    if (normalizedUnit == 'nghin' ||
        normalizedUnit == 'ngan' ||
        normalizedUnit == 'k') {
      return value * 1000;
    }

    return value;
  }

  int _scoreAmount(String raw, String? unit) {
    final normalizedRaw = _normalize(raw);
    final normalizedUnit = unit == null ? '' : _normalize(unit);

    int score = 0;

    if (raw.contains('+') || raw.contains('-')) score += 3;
    if (normalizedUnit == 'k' ||
        normalizedUnit == 'nghin' ||
        normalizedUnit == 'ngan' ||
        normalizedUnit == 'tr' ||
        normalizedUnit == 'trieu') {
      score += 2;
    }

    if (normalizedRaw.contains('vnd') ||
        normalizedRaw.contains('d') ||
        normalizedRaw.contains('đ')) {
      score += 1;
    }

    return score;
  }

  String _detectType({required String normalizedInput, required String? sign}) {
    if (sign == '+') return 'income';
    if (sign == '-') return 'expense';

    final incomeKeywords = [
      'luong',
      'thuong',
      'bonus',
      'lam them',
      'freelance',
      'nhan tien',
      'duoc chuyen khoan',
      'tien ve',
      'thu nhap',
      'lai',
      'co tuc',
    ];

    for (final keyword in incomeKeywords) {
      if (normalizedInput.contains(keyword)) {
        return 'income';
      }
    }

    return 'expense';
  }

  String _detectCategory({
    required String normalizedInput,
    required String normalizedTitle,
    required String type,
  }) {
    final text = '$normalizedInput $normalizedTitle';

    if (type == 'income') {
      if (_containsAny(text, ['luong', 'salary'])) return 'Lương';
      if (_containsAny(text, ['lam them', 'freelance', 'job'])) {
        return 'Làm thêm';
      }
      if (_containsAny(text, ['thuong', 'bonus'])) return 'Thưởng';
      if (_containsAny(text, ['dau tu', 'co tuc', 'lai'])) return 'Đầu tư';

      return 'Lương';
    }

    if (_containsAny(text, [
      'hu tieu',
      'pho',
      'bun',
      'com',
      'banh mi',
      'mi',
      'chao',
      'an',
      'an sang',
      'an trua',
      'an toi',
      'tra sua',
      'ga',
      'lau',
      'nuong',
      'quan an',
      'nha hang',
      'food',
      'restaurant',
    ])) {
      return 'Ăn uống';
    }

    if (_containsAny(text, [
      'cafe',
      'ca phe',
      'coffee',
      'highlands',
      'phuc long',
      'the coffee house',
      'starbucks',
    ])) {
      return 'Ăn uống';
    }

    if (_containsAny(text, [
      'xang',
      'grab',
      'be ',
      'taxi',
      'bus',
      'xe',
      'gui xe',
      'di chuyen',
      'petrol',
      'fuel',
    ])) {
      return 'Di chuyển';
    }

    if (_containsAny(text, [
      'mua',
      'ao',
      'quan',
      'giay',
      'dep',
      'shop',
      'sieu thi',
      'winmart',
      'coopmart',
      'bach hoa xanh',
      'circle k',
      'ministop',
      'shopping',
    ])) {
      return 'Mua sắm';
    }

    if (_containsAny(text, [
      'dien',
      'nuoc',
      'internet',
      'wifi',
      'viettel',
      'fpt',
      'hoa don',
      'bill',
    ])) {
      return 'Hóa đơn';
    }

    if (_containsAny(text, [
      'thuoc',
      'nha thuoc',
      'benh vien',
      'kham',
      'suc khoe',
      'pharmacy',
      'clinic',
    ])) {
      return 'Sức khỏe';
    }

    if (_containsAny(text, [
      'hoc',
      'sach',
      'khoa hoc',
      'giao duc',
      'truong',
      'school',
    ])) {
      return 'Giáo dục';
    }

    if (_containsAny(text, ['nha', 'tro', 'phong', 'thue nha', 'noi that'])) {
      return 'Nhà cửa';
    }

    return 'Ăn uống';
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }

    return false;
  }

  String _cleanTitle(String value) {
    String result = value;

    final removeWords = [
      'het',
      'mất',
      'mat',
      'giá',
      'gia',
      'tiền',
      'tien',
      'vnd',
      'vnđ',
      'dong',
      'đồng',
      'nghìn',
      'nghin',
      'ngàn',
      'ngan',
      'triệu',
      'trieu',
    ];

    for (final word in removeWords) {
      result = result.replaceAll(
        RegExp('\\b$word\\b', caseSensitive: false, unicode: true),
        ' ',
      );
    }

    result = result
        .replaceAll('+', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (result.isEmpty) return '';

    return _capitalizeFirst(result);
  }

  String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  String _normalize(String value) {
    var text = value.toLowerCase().trim();

    const vietnamese = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    vietnamese.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }
}

class _AmountInfo {
  final String rawText;
  final double amount;
  final String? sign;

  const _AmountInfo({
    required this.rawText,
    required this.amount,
    required this.sign,
  });
}
