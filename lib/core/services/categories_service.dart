import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// كائن يمثل تصنيفاً مالياً (إيراد أو مصروف)
class FinancialCategory {
  const FinancialCategory({
    required this.id,
    required this.name,
    required this.type,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String type; // 'income' | 'expense'
  final bool isBuiltIn;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'isBuiltIn': isBuiltIn,
      };

  factory FinancialCategory.fromMap(Map<String, dynamic> map) {
    return FinancialCategory(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      type: (map['type'] ?? 'expense') as String,
      isBuiltIn: (map['isBuiltIn'] ?? false) as bool,
    );
  }
}

/// خدمة مركزية لإدارة التصنيفات المالية مع دعم الـ Cache (Offline-first)
/// والتصنيفات الافتراضية المدمجة.
class CategoriesService {
  CategoriesService({
    required FirebaseFirestore firestore,
    required HiveService hive,
  })  : _firestore = firestore,
        _hive = hive {
    _initFromCache();
    _listenToRemoteChanges();
  }

  final FirebaseFirestore _firestore;
  final HiveService _hive;

  static const List<FinancialCategory> _defaultExpenseCategories = [
    FinancialCategory(id: AppExpenseCategories.salaries, name: 'رواتب', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.rent, name: 'إيجار', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.utilities, name: 'مرافق', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.maintenance, name: 'صيانة', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.supplies, name: 'مستلزمات', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.quranCopiesPurchase, name: 'شراء مصاحف', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.fansPurchase, name: 'شراء مراوح', type: AppTransactionTypes.expense, isBuiltIn: true),
    FinancialCategory(id: AppExpenseCategories.otherExpense, name: 'مصروفات أخرى', type: AppTransactionTypes.expense, isBuiltIn: true),
  ];

  static const List<FinancialCategory> _defaultIncomeCategories = [
    FinancialCategory(id: AppIncomeCategories.studentSubscription, name: 'اشتراكات الطلاب', type: AppTransactionTypes.income, isBuiltIn: true),
    FinancialCategory(id: AppIncomeCategories.donation, name: 'تبرعات', type: AppTransactionTypes.income, isBuiltIn: true),
    FinancialCategory(id: AppIncomeCategories.loanRepayment, name: 'سداد سلفة', type: AppTransactionTypes.income, isBuiltIn: true),
    FinancialCategory(id: AppIncomeCategories.otherIncome, name: 'إيرادات أخرى', type: AppTransactionTypes.income, isBuiltIn: true),
    FinancialCategory(id: AppIncomeCategories.openingBalance, name: 'رصيد افتتاحي', type: AppTransactionTypes.income, isBuiltIn: true),
  ];

  final _controller = StreamController<List<FinancialCategory>>.broadcast();
  List<FinancialCategory> _categories = [];
  StreamSubscription? _sub;

  Stream<List<FinancialCategory>> watchCategories() => _controller.stream;
  List<FinancialCategory> get allCategories => List.unmodifiable(_categories);

  List<FinancialCategory> get expenseCategories =>
      _categories.where((c) => c.type == AppTransactionTypes.expense).toList();

  List<FinancialCategory> get incomeCategories =>
      _categories.where((c) => c.type == AppTransactionTypes.income).toList();

  String getLabel(String id) {
    final cat = _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => FinancialCategory(id: id, name: id, type: 'unknown'),
    );
    return cat.name;
  }

  void _initFromCache() {
    final cached = _hive.getCachedList(AppCollections.cacheCategoriesBox);
    final items = cached?.items ?? const <Map<String, dynamic>>[];
    final map = <String, FinancialCategory>{};
    for (final def in [..._defaultExpenseCategories, ..._defaultIncomeCategories]) {
      map[def.id] = def;
    }
    for (final item in items) {
      final cat = FinancialCategory.fromMap(item);
      map[cat.id] = cat;
    }
    _categories = map.values.toList();
    _controller.add(_categories);
  }

  void _listenToRemoteChanges() {
    _sub = _firestore
        .collection(AppCollections.categories)
        .snapshots()
        .listen((snapshot) async {
      final remoteCategories = <FinancialCategory>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        remoteCategories.add(FinancialCategory(
          id: doc.id,
          name: (data['name'] ?? doc.id) as String,
          type: (data['type'] ?? AppTransactionTypes.expense) as String,
          isBuiltIn: false,
        ));
      }

      final map = <String, FinancialCategory>{};
      for (final def in [..._defaultExpenseCategories, ..._defaultIncomeCategories]) {
        map[def.id] = def;
      }
      for (final c in remoteCategories) {
        map[c.id] = c;
      }

      _categories = map.values.toList();
      _controller.add(_categories);

      // حفظ في Hive محلياً للعمل بدون إنترنت
      await _hive.cacheList(
        AppCollections.cacheCategoriesBox,
        remoteCategories.map((c) => c.toMap()).toList(),
      );
    }, onError: (_) {
      // الاعتماد على الكاش عند فشل الاتصال
    });
  }

  /// إضافة تصنيف جديد بواسطة المدير
  Future<void> addCategory({
    required String name,
    required String type,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('اسم التصنيف يجب ألا يقل عن حرفين');
    }

    // توليد معرف قياسي أو معرّف عشوائي نظيف
    final id = cleanName
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\u0600-\u06FF]'), '');

    final docRef = _firestore.collection(AppCollections.categories).doc(id.isEmpty ? null : id);
    await docRef.set({
      'name': cleanName,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
