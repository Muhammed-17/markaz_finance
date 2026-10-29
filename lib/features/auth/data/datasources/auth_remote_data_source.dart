import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/data/models/user_model.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/constants/app_constants.dart';

/// مصدر بيانات المصادقة البعيد: Firebase Auth + مجموعة users في Firestore.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required ConnectivityService connectivityService,
  })  : _auth = auth,
        _firestore = firestore,
        _connectivity = connectivityService;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ConnectivityService _connectivity;

  /// نسخة مشتركة تضمن ظهور اختيار الحساب في كل مرة (forceCodeForRefreshToken)
  final _googleSignIn = GoogleSignIn(forceCodeForRefreshToken: true);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppCollections.users);

  /// بث تغيرات المستخدم المسجل من Firebase Auth (null عند الخروج).
  Stream<User?> observeAuthUser() => _auth.authStateChanges();

  /// بث مستند المستخدم من Firestore — المصدر الموثوق للدور والصلاحيات.
  Stream<UserModel?> observeProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromSnapshot(snapshot);
    });
  }

  /// جلب المستند الحالي مرة واحدة.
  Future<UserModel?> fetchProfile(String uid) async {
    final snapshot = await _usersCollection.doc(uid).get();
    if (!snapshot.exists) return null;
    return UserModel.fromSnapshot(snapshot);
  }

  /// تسجيل الدخول بالبريد وكلمة المرور، ثم جلب المستند الموثوق.
  /// يرفض الحسابات المعطلة صراحةً ويخرج فورًا.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    await _ensureOnline();

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const UnauthenticatedException('تعذر تسجيل الدخول، حاول مرة أخرى');
    }

    final profile = await fetchProfile(user.uid);
    if (profile == null) {
      // حساب في Auth بلا مستند: لا صلاحيات — خروج فوري.
      await _auth.signOut();
      throw const PermissionDeniedException(
        'حسابك غير مسجل في النظام، تواصل مع الإدارة',
      );
    }

    if (!profile.isActive) {
      await _auth.signOut();
      throw const PermissionDeniedException(
        'تم تعطيل هذا الحساب، تواصل مع الإدارة',
      );
    }

    return profile;
  }

  /// ينشئ حساب Google الجديد كسجل غير فعّال بلا صلاحيات. لا يكفي نجاح
  /// Firebase Authentication للدخول؛ يتطلب التطبيق اعتماد المدير لـ isActive.
  Future<UserModel> signInWithGoogle() async {
    await _ensureOnline();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const OperationRejectedException(
          'تم إلغاء تسجيل الدخول عبر Google',
        );
      }

      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const UnauthenticatedException('تعذر الحصول على حساب Google');
      }

      final reference = _usersCollection.doc(user.uid);
      final snapshot = await reference.get();
      final UserModel profile;
      if (snapshot.exists) {
        profile = UserModel.fromSnapshot(snapshot);
      } else {
        profile = UserModel(
          id: user.uid,
          name: user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'مستخدم جديد'),
          email: user.email?.trim() ?? '',
          role: 'user',
          financialPermissions: const FinancialPermissions.none().toRawMap(),
          isActive: false,
        );
        await reference.set(profile.toMap());
      }

      if (!profile.isActive) {
        await _auth.signOut();
        throw const OperationRejectedException(
          'تم إرسال طلب الانضمام، وينتظر تفعيل المسؤول',
        );
      }
      return profile;
    } on AppException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw UnauthenticatedException(
        error.message ?? 'تعذر تسجيل الدخول عبر Google',
      );
    } catch (_) {
      throw const OperationRejectedException('تعذر تسجيل الدخول عبر Google');
    }
  }

  /// تسجيل الخروج — يطهّر جلسة Google تمامًا حتى يظهر منتقي الحساب في الدخول التالي.
  Future<void> signOut() async {
    await _auth.signOut();
    // disconnect() تزيل رمز التحديث وتجبر Google على عرض منتقي الحساب في المرة القادمة.
    // نتجاهل الأخطاء إن لم تكن جلسة Google نشطة (مثلاً: تسجيل دخول بالبريد).
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
  }

  Future<void> _ensureOnline() async {
    final online = await _connectivity.checkNow();
    if (!online) {
      throw const NetworkException(
        'تسجيل الدخول يتطلب اتصالًا بالإنترنت — تحقق من اتصالك',
      );
    }
  }
}
