import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/center_model.dart';

/// مصدر بيانات المراكز البعيد (Firestore).
///
/// قواعد الميزة:
/// - الحقول المسموحة فقط: name, description, createdAt, updatedAt.
/// - الطوابع الزمنية من الخادم دائمًا (FieldValue.serverTimestamp).
/// - الكتابة مباشرة على Firestore؛ قواعد الأمان تسمح للمديرين فقط
///   وفي حال الرفض يظهر الخطأ القادم من الخادم للمستخدم.
class CentersRemoteDataSource {
  CentersRemoteDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _centers =>
      _firestore.collection(AppCollections.centers);

  /// بث قائمة المراكز مرتبة بالاسم.
  Stream<List<CenterModel>> streamCenters() {
    return _centers.orderBy('name').snapshots().map(
          (snapshot) =>
              snapshot.docs.map(CenterModel.fromSnapshot).toList(),
        );
  }

  /// جلب قائمة المراكز مرتبة بالاسم (قراءة لمرة واحدة).
  Future<List<CenterModel>> fetchCenters() async {
    final snapshot = await _centers.orderBy('name').get();
    return snapshot.docs.map(CenterModel.fromSnapshot).toList();
  }

  /// إضافة مركز جديد بمعرّف مولّد تلقائيًا.
  Future<void> addCenter({
    required String name,
    String? description,
  }) async {
    await _centers.add(<String, dynamic>{
      'name': name,
      'description': description ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تعديل مركز موجود — يكتب الحقول القابلة للتعديل مع updatedAt فقط.
  Future<void> updateCenter({
    required String id,
    required String name,
    String? description,
  }) async {
    await _centers.doc(id).update(<String, dynamic>{
      'name': name,
      'description': description ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
