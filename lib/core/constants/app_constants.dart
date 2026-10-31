/// أسماء مجموعات Firestore (المجموعات العشر المعتمدة فقط).
abstract final class AppCollections {
  static const String centers = 'centers';
  static const String branches = 'branches';
  static const String users = 'users';
  static const String fundEnvelopes = 'fundEnvelopes';
  static const String transactions = 'transactions';
  static const String envelopeTransactions = 'envelopeTransactions';
  static const String transactionLogs = 'transactionLogs';
  static const String employeeLoans = 'employeeLoans';
  static const String loanPayments = 'loanPayments';
  static const String loanLogs = 'loanLogs';
  static const String categories = 'categories';

  /// أسماء صناديق Hive للتخزين المؤقت.
  static const String settingsBox = 'app_settings';
  static const String draftsBox = 'app_drafts';
  static const String cacheCentersBox = 'cache_centers';
  static const String cacheBranchesBox = 'cache_branches';
  static const String cacheEnvelopesBox = 'cache_envelopes';
  static const String cacheUsersBox = 'cache_users';
  static const String cacheCategoriesBox = 'cache_categories';
  static const String pendingOperationsBox = 'app_pending_operations';
}

/// أدوار المستخدمين (String وليس enum في قاعدة البيانات).
abstract final class AppRoles {
  static const String admin = 'admin';
  static const String user = 'user';
  static const List<String> all = [admin, user];
}

/// مفاتيح الصلاحيات المالية داخل حقل financialPermissions.
///
/// القراءة متاحة لكل مستخدم نشط؛ لذلك لا توجد صلاحية `view` مستقلة.
abstract final class AppPermissions {
  static const String create = 'create';
  static const String update = 'update';
  static const String cancel = 'cancel';
  static const String approve = 'approve';
  static const List<String> all = [create, update, cancel, approve];
}

/// أنواع الحركات المالية.
abstract final class AppTransactionTypes {
  static const String income = 'income';
  static const String expense = 'expense';
  static const List<String> all = [income, expense];
}

/// تصنيفات الإيرادات المعتمدة (قيم نصية يتحقق منها الخادم).
abstract final class AppIncomeCategories {
  static const String studentSubscription = 'student_subscription';
  static const String donation = 'donation';
  static const String loanRepayment = 'loan_repayment';
  static const String otherIncome = 'other_income';
  static const String openingBalance = 'opening_balance';

  /// التصنيفات التي يمكن إنشاؤها يدويًا من شاشة الحركات.
  /// (loan_repayment تُنشأ آليًا عبر دالة repayLoan فقط)
  static const List<String> creatable = [
    studentSubscription,
    donation,
    otherIncome,
    openingBalance,
  ];

  /// كل التصنيفات (للعرض في التقارير والتصفية).
  static const List<String> all = [
    studentSubscription,
    donation,
    loanRepayment,
    otherIncome,
    openingBalance,
  ];
}

/// تصنيفات المصروفات المعتمدة.
abstract final class AppExpenseCategories {
  static const String employeeLoan = 'employee_loan';
  static const String salaries = 'salaries';
  static const String rent = 'rent';
  static const String utilities = 'utilities';
  static const String maintenance = 'maintenance';
  static const String supplies = 'supplies';
  static const String quranCopiesPurchase = 'quran_copies_purchase';
  static const String fansPurchase = 'fans_purchase';
  static const String otherExpense = 'other_expense';

  /// التصنيفات التي يمكن إنشاؤها يدويًا من شاشة الحركات.
  /// (employee_loan يُنشأ آليًا عبر دالة createEmployeeLoan فقط)
  static const List<String> creatable = [
    salaries,
    rent,
    utilities,
    maintenance,
    supplies,
    quranCopiesPurchase,
    fansPurchase,
    otherExpense,
  ];

  /// كل التصنيفات (للعرض في التقارير والتصفية وخيارات الأظرف).
  static const List<String> all = [
    employeeLoan,
    salaries,
    rent,
    utilities,
    maintenance,
    supplies,
    quranCopiesPurchase,
    fansPurchase,
    otherExpense,
  ];
}

/// طرق الدفع/التحصيل.
abstract final class AppPaymentMethods {
  static const String cash = 'cash';
  static const String vodafoneCash = 'vodafone_cash';
  static const String bankTransfer = 'bank_transfer';
  static const String cheque = 'cheque';
  static const String other = 'other';
  static const List<String> all = [cash, vodafoneCash, bankTransfer, cheque, other];
}

/// أنواع حركات الأظرف (envelopeTransactions).
abstract final class AppEnvelopeTransactionTypes {
  static const String income = 'income';
  static const String expense = 'expense';
  static const String allocation = 'allocation';
  static const String transferIn = 'transfer_in';
  static const String transferOut = 'transfer_out';
  static const String refund = 'refund';
  static const String adjustment = 'adjustment';
  static const List<String> all = [
    income, expense, allocation, transferIn, transferOut, refund, adjustment,
  ];

  /// أنواع التحويل الداخلي بين الأظرف (لا تُحسب إيرادًا أو مصروفًا للخزنة).
  static const List<String> transferTypes = [transferIn, transferOut];
}

/// أنواع صناديق الأموال.
abstract final class AppFundTypes {
  static const String general = 'general';
  static const String restricted = 'restricted';
  static const List<String> all = [general, restricted];
}

/// حالات السجلات والحركات.
abstract final class AppStatuses {
  static const String active = 'active';
  static const String archived = 'archived';
  static const String cancelled = 'cancelled';
  static const String paidOff = 'paid_off';
}

/// أنواع إجراءات سجلات التدقيق.
abstract final class AppLogActions {
  static const String create = 'CREATE';
  static const String update = 'UPDATE';
  static const String cancel = 'CANCEL';
  static const String payment = 'PAYMENT';
  static const String payoff = 'PAYOFF';
}

/// معرفات العمليات المالية العشر — تُنفَّذ محليًا عبر معاملات Firestore
/// الذرية في FinancialOperationsService (بدل معاملات Firestore الذرية المدفوعة)،
/// وتحميها قواعد أمان Firestore الصارمة على الخادم.
/// الأسماء محفوظة كما هي لعقد الاستدعاء في مصادر البيانات.
abstract final class AppFunctions {
  static const String region = 'europe-west1';
  static const String createTransaction = 'createTransaction';
  static const String updateTransaction = 'updateTransaction';
  static const String cancelTransaction = 'cancelTransaction';
  static const String transferBetweenEnvelopes = 'transferBetweenEnvelopes';
  static const String createEnvelope = 'createEnvelope';
  static const String updateEnvelope = 'updateEnvelope';
  static const String archiveEnvelope = 'archiveEnvelope';
  static const String createEmployeeLoan = 'createEmployeeLoan';
  static const String repayLoan = 'repayLoan';
  static const String createUser = 'createUser';
  static const String updateUser = 'updateUser';
}

/// مسارات مرفقات التخزين.
abstract final class AppStoragePaths {
  static const String attachmentsPrefix = 'attachments/';
}
