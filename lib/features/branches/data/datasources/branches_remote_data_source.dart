import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../models/branch_model.dart';

/// مصدر بيانات الفروع البعيد (Firestore).
///
/// قواعد الميزة:
/// - الحقول المسموحة فقط: centerId, name, location, createdAt, updatedAt.
/// - الطوابع الزمنية من الخادم دائمًا (FieldValue.serverTimestamp).
/// - استعلام الفروع: مساواة centerId == X فقط أو الكل،
///   والترتيب بالاسم يتم على العميل بعد الجلب.
/// - الكتابة مباشرة على Firestore؛ قواعد الأمان تسمح للمديرين فقط
///   وفي حال الرفض يظهر الخطأ القادم من الخادم للمستخدم.
class BranchesRemoteDataSource {
  BranchesRemoteDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection(AppCollections.branches);

  /// بث قائمة الفروع (مرتبة بالاسم على العميل).
  Stream<List<BranchModel>> streamBranches({String? centerId}) {
    Query<Map<String, dynamic>> query = _branches;
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    return query.snapshots().map(
          (snapshot) => _sorted(
            snapshot.docs.map(BranchModel.fromSnapshot).toList(),
          ),
        );
  }

  /// جلب قائمة الفروع (مرتبة بالاسم على العميل).
  Future<List<BranchModel>> fetchBranches({String? centerId}) async {
    Query<Map<String, dynamic>> query = _branches;
    if (centerId != null) {
      query = query.where('centerId', isEqualTo: centerId);
    }
    final snapshot = await query.get();
    return _sorted(
      snapshot.docs.map(BranchModel.fromSnapshot).toList(),
    );
  }

  /// قائمة مرجعية مبسطة للمراكز لعرضها في الفلاتر والنماذج
  /// (قراءة فقط من مجموعة centers مرتبة بالاسم).
  Future<List<CenterRef>> fetchCentersForFilter() async {
    final snapshot =
        await _firestore.collection(AppCollections.centers).orderBy('name').get();
    return snapshot.docs
        .map(
          (doc) => CenterRef(
            id: doc.id,
            name: (doc.data()['name'] ?? '') as String,
          ),
        )
        .toList();
  }

  /// إضافة فرع جديد بمعرّف مولّد تلقائيًا.
  Future<void> addBranch({
    required String centerId,
    required String name,
    String? location,
  }) async {
    await _branches.add(<String, dynamic>{
      'centerId': centerId,
      'name': name,
      'location': location ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تعديل فرع موجود — يكتب الحقول القابلة للتعديل مع updatedAt فقط.
  Future<void> updateBranch({
    required String id,
    required String centerId,
    required String name,
    String? location,
  }) async {
    await _branches.doc(id).update(<String, dynamic>{
      'centerId': centerId,
      'name': name,
      'location': location ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// الترتيب بالاسم يتم على العميل بعد الجلب (حسب قيود الاستعلام).
  static List<BranchModel> _sorted(List<BranchModel> models) {
    return models
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  }
}
