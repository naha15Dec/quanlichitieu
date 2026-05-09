import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../models/budget_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';

class ChatbotService {
  String generateResponse({
    required String message,
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
    required List<RecurringTransactionModel> recurringItems,
  }) {
    final normalized = _normalize(message);

    if (_isHelpIntent(normalized)) {
      return _helpResponse();
    }

    if (_isGreetingIntent(normalized)) {
      return 'Chào bạn 👋 Mình là trợ lý tài chính của Smart Expense. Bạn có thể hỏi mình về chi tiêu, thu nhập, ngân sách, danh mục chi nhiều nhất hoặc giao dịch định kỳ.';
    }

    if (_isTodayExpenseIntent(normalized)) {
      return _todayExpenseResponse(transactions);
    }

    if (_isWeekExpenseIntent(normalized)) {
      return _weekExpenseResponse(transactions);
    }

    if (_isMonthExpenseIntent(normalized)) {
      return _monthExpenseResponse(transactions);
    }

    if (_isMonthIncomeIntent(normalized)) {
      return _monthIncomeResponse(transactions);
    }

    if (_isBalanceIntent(normalized)) {
      return _monthBalanceResponse(transactions);
    }

    if (_isRemainingBudgetIntent(normalized)) {
      return _remainingBudgetResponse(
        transactions: transactions,
        budget: budget,
      );
    }

    if (_isBudgetStatusIntent(normalized)) {
      return _budgetStatusResponse(transactions: transactions, budget: budget);
    }

    if (_isTopCategoryIntent(normalized)) {
      return _topCategoryResponse(transactions);
    }

    final categoryResponse = _categoryExpenseResponse(
      normalized: normalized,
      transactions: transactions,
    );

    if (categoryResponse != null) {
      return categoryResponse;
    }

    if (_isCompareMonthIntent(normalized)) {
      return _compareMonthResponse(transactions);
    }

    if (_isCompareWeekIntent(normalized)) {
      return _compareWeekResponse(transactions);
    }

    if (_isRecurringDueIntent(normalized)) {
      return _recurringDueResponse(recurringItems);
    }

    if (_isRecurringNextIntent(normalized)) {
      return _recurringNextResponse(recurringItems);
    }

    if (_isRecentTransactionIntent(normalized)) {
      return _recentTransactionResponse(transactions);
    }

    if (_isTransactionCountIntent(normalized)) {
      return _transactionCountResponse(transactions);
    }

    if (_isAverageDailyExpenseIntent(normalized)) {
      return _averageDailyExpenseResponse(transactions);
    }

    return 'Mình chưa hiểu rõ câu hỏi này. Bạn có thể hỏi mình về: chi tiêu tháng này, thu nhập tháng này, ngân sách còn lại, danh mục chi nhiều nhất, so sánh tháng trước hoặc giao dịch định kỳ đến hạn.';
  }

  String _normalize(String input) {
    var text = input.toLowerCase().trim();

    const vietnameseMap = {
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

    vietnameseMap.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  bool _containsAny(String text, List<String> words) {
    return words.any(text.contains);
  }

  bool _isHelpIntent(String text) {
    return _containsAny(text, [
      'ban lam duoc gi',
      'bot lam duoc gi',
      'tro giup',
      'huong dan',
      'hoi gi duoc',
      'co the hoi gi',
    ]);
  }

  bool _isGreetingIntent(String text) {
    return text == 'hi' ||
        text == 'hello' ||
        text == 'chao' ||
        text == 'xin chao' ||
        text == 'hey';
  }

  bool _isTodayExpenseIntent(String text) {
    return _containsAny(text, ['hom nay']) &&
        _containsAny(text, ['chi', 'tieu', 'ton', 'xai']);
  }

  bool _isWeekExpenseIntent(String text) {
    return _containsAny(text, ['tuan nay', 'trong tuan']) &&
        _containsAny(text, ['chi', 'tieu', 'ton', 'xai']);
  }

  bool _isMonthExpenseIntent(String text) {
    return _containsAny(text, ['thang nay', 'trong thang']) &&
        _containsAny(text, ['chi', 'tieu', 'ton', 'xai']);
  }

  bool _isMonthIncomeIntent(String text) {
    return _containsAny(text, ['thang nay', 'trong thang']) &&
        _containsAny(text, [
          'thu',
          'thu nhap',
          'kiem duoc',
          'nhan duoc',
          'luong',
        ]);
  }

  bool _isBalanceIntent(String text) {
    return _containsAny(text, ['so du', 'con lai', 'thu chi', 'chenh lech']) &&
        !_containsAny(text, ['ngan sach']);
  }

  bool _isRemainingBudgetIntent(String text) {
    return _containsAny(text, ['ngan sach']) &&
        _containsAny(text, ['con', 'con lai', 'bao nhieu']);
  }

  bool _isBudgetStatusIntent(String text) {
    return _containsAny(text, ['ngan sach']) &&
        _containsAny(text, ['vuot', 'sap het', 'het', 'trang thai', 'da dung']);
  }

  bool _isTopCategoryIntent(String text) {
    return _containsAny(text, [
      'danh muc nao',
      'muc nao',
      'chi nhieu nhat',
      'ton nhieu nhat',
      'top danh muc',
      'cao nhat',
    ]);
  }

  bool _isCompareMonthIntent(String text) {
    return _containsAny(text, ['thang nay']) &&
        _containsAny(text, [
          'thang truoc',
          'so voi',
          'cao hon',
          'thap hon',
          'tang',
          'giam',
        ]);
  }

  bool _isCompareWeekIntent(String text) {
    return _containsAny(text, ['tuan nay']) &&
        _containsAny(text, [
          'tuan truoc',
          'so voi',
          'cao hon',
          'thap hon',
          'tang',
          'giam',
        ]);
  }

  bool _isRecurringDueIntent(String text) {
    return _containsAny(text, ['dinh ky', 'lap lai', 'den han', 'toi han']) &&
        _containsAny(text, ['co', 'nao', 'chua', 'khong']);
  }

  bool _isRecurringNextIntent(String text) {
    return _containsAny(text, ['dinh ky', 'lap lai']) &&
        _containsAny(text, ['tiep theo', 'sap toi', 'gan nhat']);
  }

  bool _isRecentTransactionIntent(String text) {
    return _containsAny(text, ['gan day', 'moi nhat', 'giao dich cuoi']);
  }

  bool _isTransactionCountIntent(String text) {
    return _containsAny(text, [
      'bao nhieu giao dich',
      'so giao dich',
      'may giao dich',
    ]);
  }

  bool _isAverageDailyExpenseIntent(String text) {
    return _containsAny(text, ['trung binh']) &&
        _containsAny(text, ['moi ngay', '1 ngay', 'mot ngay']);
  }

  String _helpResponse() {
    return 'Mình có thể giúp bạn:\n'
        '• Xem chi tiêu hôm nay, tuần này, tháng này\n'
        '• Xem thu nhập và số dư tháng này\n'
        '• Kiểm tra ngân sách còn lại hoặc đã vượt chưa\n'
        '• Tìm danh mục chi nhiều nhất\n'
        '• So sánh chi tiêu tuần/tháng trước\n'
        '• Kiểm tra giao dịch định kỳ đến hạn\n\n'
        'Ví dụ: "Tháng này tôi chi bao nhiêu?", "Tôi còn bao nhiêu ngân sách?", "Danh mục nào chi nhiều nhất?"';
  }

  String _todayExpenseResponse(List<TransactionModel> transactions) {
    final now = DateTime.now();

    final todayTransactions = transactions.where((item) {
      return item.type == 'expense' &&
          item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day;
    }).toList();

    final total = todayTransactions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (total <= 0) {
      return 'Hôm nay bạn chưa ghi nhận khoản chi nào.';
    }

    return 'Hôm nay bạn đã chi ${CurrencyFormatter.formatVND(total)} với ${todayTransactions.length} giao dịch.';
  }

  String _weekExpenseResponse(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final weekTransactions = transactions.where((item) {
      final date = _dateOnly(item.date);
      return item.type == 'expense' &&
          !date.isBefore(startOfWeek) &&
          !date.isAfter(endOfWeek);
    }).toList();

    final total = weekTransactions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (total <= 0) {
      return 'Tuần này bạn chưa có khoản chi nào.';
    }

    return 'Tuần này bạn đã chi ${CurrencyFormatter.formatVND(total)} với ${weekTransactions.length} giao dịch.';
  }

  String _monthExpenseResponse(List<TransactionModel> transactions) {
    final monthTransactions = _currentMonthTransactions(
      transactions,
    ).where((item) => item.type == 'expense').toList();

    final total = monthTransactions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (total <= 0) {
      return 'Tháng này bạn chưa có khoản chi nào.';
    }

    return 'Tháng này bạn đã chi ${CurrencyFormatter.formatVND(total)} với ${monthTransactions.length} giao dịch.';
  }

  String _monthIncomeResponse(List<TransactionModel> transactions) {
    final incomeTransactions = _currentMonthTransactions(
      transactions,
    ).where((item) => item.type == 'income').toList();

    final total = incomeTransactions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (total <= 0) {
      return 'Tháng này bạn chưa ghi nhận khoản thu nhập nào.';
    }

    return 'Tháng này bạn đã có tổng thu nhập ${CurrencyFormatter.formatVND(total)} từ ${incomeTransactions.length} giao dịch.';
  }

  String _monthBalanceResponse(List<TransactionModel> transactions) {
    final currentMonth = _currentMonthTransactions(transactions);

    final income = _sumByType(currentMonth, 'income');
    final expense = _sumByType(currentMonth, 'expense');
    final balance = income - expense;

    return 'Số dư tháng này là ${CurrencyFormatter.formatVND(balance)}.\n'
        'Thu nhập: ${CurrencyFormatter.formatVND(income)}\n'
        'Chi tiêu: ${CurrencyFormatter.formatVND(expense)}';
  }

  String _remainingBudgetResponse({
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
  }) {
    if (budget == null || budget.totalAvailable <= 0) {
      return 'Bạn chưa thiết lập ngân sách tháng này. Hãy vào mục Ngân sách để tạo ngân sách trước.';
    }

    final expense = _sumByType(
      _currentMonthTransactions(transactions),
      'expense',
    );
    final remaining = budget.totalAvailable - expense;
    final progress = expense / budget.totalAvailable * 100;

    if (remaining < 0) {
      return 'Bạn đã vượt ngân sách ${CurrencyFormatter.formatVND(remaining.abs())}. Mức sử dụng hiện tại là ${progress.toStringAsFixed(1)}%.';
    }

    return 'Bạn còn ${CurrencyFormatter.formatVND(remaining)} trong ngân sách tháng này. Bạn đã sử dụng ${progress.toStringAsFixed(1)}% ngân sách.';
  }

  String _budgetStatusResponse({
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
  }) {
    if (budget == null || budget.totalAvailable <= 0) {
      return 'Bạn chưa có ngân sách tháng này nên mình chưa thể đánh giá trạng thái ngân sách.';
    }

    final expense = _sumByType(
      _currentMonthTransactions(transactions),
      'expense',
    );
    final progress = expense / budget.totalAvailable;

    if (progress >= 1) {
      return 'Bạn đã vượt ngân sách tháng này. Tổng chi hiện tại là ${CurrencyFormatter.formatVND(expense)}, trong khi ngân sách khả dụng là ${CurrencyFormatter.formatVND(budget.totalAvailable)}.';
    }

    if (progress >= 0.8) {
      return 'Bạn sắp vượt ngân sách. Hiện đã dùng ${(progress * 100).toStringAsFixed(1)}% ngân sách tháng.';
    }

    return 'Ngân sách tháng này đang an toàn. Bạn đã dùng ${(progress * 100).toStringAsFixed(1)}% ngân sách.';
  }

  String _topCategoryResponse(List<TransactionModel> transactions) {
    final categoryStats = _categoryStats(
      _currentMonthTransactions(transactions),
    );

    if (categoryStats.isEmpty) {
      return 'Tháng này chưa có dữ liệu chi tiêu theo danh mục.';
    }

    final top = categoryStats.entries.first;
    final totalExpense = categoryStats.values.fold<double>(0, (s, v) => s + v);
    final ratio = top.value / totalExpense * 100;

    return 'Danh mục chi nhiều nhất tháng này là "${top.key}" với ${CurrencyFormatter.formatVND(top.value)}, chiếm ${ratio.toStringAsFixed(1)}% tổng chi tiêu.';
  }

  String? _categoryExpenseResponse({
    required String normalized,
    required List<TransactionModel> transactions,
  }) {
    final knownCategories = <String, String>{
      'an uong': 'Ăn uống',
      'ca phe': 'Ăn uống',
      'mua sam': 'Mua sắm',
      'di chuyen': 'Di chuyển',
      'xang xe': 'Di chuyển',
      'hoc tap': 'Học tập',
      'giai tri': 'Giải trí',
      'suc khoe': 'Sức khỏe',
      'nha cua': 'Nhà cửa',
      'tien tro': 'Nhà cửa',
      'luong': 'Lương',
      'lam them': 'Làm thêm',
    };

    String? matchedDisplayCategory;

    for (final entry in knownCategories.entries) {
      if (normalized.contains(entry.key)) {
        matchedDisplayCategory = entry.value;
        break;
      }
    }

    if (matchedDisplayCategory == null) {
      return null;
    }

    final askExpense = _containsAny(normalized, [
      'bao nhieu',
      'het bao nhieu',
      'chi',
      'ton',
      'xai',
    ]);

    if (!askExpense) return null;

    final currentMonth = _currentMonthTransactions(transactions);

    final total = currentMonth
        .where((item) {
          return item.category.toLowerCase().trim() ==
                  matchedDisplayCategory!.toLowerCase().trim() &&
              item.type == 'expense';
        })
        .fold<double>(0, (sum, item) => sum + item.amount);

    if (total <= 0) {
      return 'Tháng này bạn chưa có khoản chi nào cho danh mục $matchedDisplayCategory.';
    }

    return 'Tháng này bạn đã chi ${CurrencyFormatter.formatVND(total)} cho danh mục $matchedDisplayCategory.';
  }

  String _compareMonthResponse(List<TransactionModel> transactions) {
    final now = DateTime.now();

    final current = transactions.where((item) {
      return item.type == 'expense' &&
          item.date.year == now.year &&
          item.date.month == now.month;
    }).toList();

    final lastMonthDate = DateTime(now.year, now.month - 1);

    final previous = transactions.where((item) {
      return item.type == 'expense' &&
          item.date.year == lastMonthDate.year &&
          item.date.month == lastMonthDate.month;
    }).toList();

    final currentTotal = current.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final previousTotal = previous.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (previousTotal <= 0) {
      return 'Mình chưa có đủ dữ liệu tháng trước để so sánh.';
    }

    final diff = currentTotal - previousTotal;
    final percent = diff / previousTotal * 100;

    if (diff > 0) {
      return 'Tháng này bạn đang chi cao hơn tháng trước khoảng ${percent.abs().toStringAsFixed(1)}%.';
    }

    if (diff < 0) {
      return 'Tháng này bạn đang chi thấp hơn tháng trước khoảng ${percent.abs().toStringAsFixed(1)}%. Đây là tín hiệu tích cực.';
    }

    return 'Chi tiêu tháng này gần như tương đương tháng trước.';
  }

  String _compareWeekResponse(List<TransactionModel> transactions) {
    final now = DateTime.now();

    final startThisWeek = _startOfWeek(now);
    final startLastWeek = startThisWeek.subtract(const Duration(days: 7));
    final endLastWeek = startLastWeek.add(const Duration(days: 6));

    final thisWeek = transactions.where((item) {
      final date = _dateOnly(item.date);
      return item.type == 'expense' &&
          !date.isBefore(startThisWeek) &&
          !date.isAfter(startThisWeek.add(const Duration(days: 6)));
    }).toList();

    final lastWeek = transactions.where((item) {
      final date = _dateOnly(item.date);
      return item.type == 'expense' &&
          !date.isBefore(startLastWeek) &&
          !date.isAfter(endLastWeek);
    }).toList();

    final thisTotal = thisWeek.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final lastTotal = lastWeek.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (lastTotal <= 0) {
      return 'Mình chưa có đủ dữ liệu tuần trước để so sánh.';
    }

    final diff = thisTotal - lastTotal;
    final percent = diff / lastTotal * 100;

    if (diff > 0) {
      return 'Tuần này bạn đang chi cao hơn tuần trước khoảng ${percent.abs().toStringAsFixed(1)}%.';
    }

    if (diff < 0) {
      return 'Tuần này bạn đang chi thấp hơn tuần trước khoảng ${percent.abs().toStringAsFixed(1)}%.';
    }

    return 'Chi tiêu tuần này gần như tương đương tuần trước.';
  }

  String _recurringDueResponse(List<RecurringTransactionModel> recurringItems) {
    final today = _dateOnly(DateTime.now());

    final dueItems = recurringItems.where((item) {
      final nextRun = _dateOnly(item.nextRunDate);
      return item.isActive && !nextRun.isAfter(today);
    }).toList();

    if (dueItems.isEmpty) {
      return 'Hiện chưa có giao dịch định kỳ nào đến hạn.';
    }

    return 'Bạn có ${dueItems.length} giao dịch định kỳ đã đến hạn. Hãy vào mục Định kỳ để tạo giao dịch thật.';
  }

  String _recurringNextResponse(
    List<RecurringTransactionModel> recurringItems,
  ) {
    final activeItems = recurringItems.where((item) => item.isActive).toList();

    if (activeItems.isEmpty) {
      return 'Bạn chưa có giao dịch định kỳ nào đang bật.';
    }

    activeItems.sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));
    final nearest = activeItems.first;

    return 'Giao dịch định kỳ sắp tới là "${nearest.title}", đến hạn vào ${DateFormatter.formatDate(nearest.nextRunDate)}.';
  }

  String _recentTransactionResponse(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return 'Bạn chưa có giao dịch nào.';
    }

    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.first;

    final prefix = recent.type == 'income' ? 'thu' : 'chi';

    return 'Giao dịch gần đây nhất là "${recent.title}" - $prefix ${CurrencyFormatter.formatVND(recent.amount)} vào ngày ${DateFormatter.formatDate(recent.date)}.';
  }

  String _transactionCountResponse(List<TransactionModel> transactions) {
    final currentMonth = _currentMonthTransactions(transactions);

    return 'Tháng này bạn có ${currentMonth.length} giao dịch.';
  }

  String _averageDailyExpenseResponse(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final expense = _sumByType(
      _currentMonthTransactions(transactions),
      'expense',
    );
    final average = expense / now.day;

    return 'Trung bình mỗi ngày trong tháng này bạn chi khoảng ${CurrencyFormatter.formatVND(average)}.';
  }

  List<TransactionModel> _currentMonthTransactions(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();

    return transactions.where((item) {
      return item.date.year == now.year && item.date.month == now.month;
    }).toList();
  }

  double _sumByType(List<TransactionModel> transactions, String type) {
    return transactions
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  Map<String, double> _categoryStats(List<TransactionModel> transactions) {
    final result = <String, double>{};

    for (final item in transactions.where((item) => item.type == 'expense')) {
      final category = item.category.trim().isEmpty ? 'Khác' : item.category;
      result[category] = (result[category] ?? 0) + item.amount;
    }

    final sorted = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  DateTime _startOfWeek(DateTime date) {
    final current = DateTime(date.year, date.month, date.day);
    return current.subtract(Duration(days: current.weekday - 1));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
