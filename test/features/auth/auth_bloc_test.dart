import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_centers_finance/core/domain/entities/user_entity.dart';
import 'package:quran_centers_finance/core/errors/failures.dart';
import 'package:quran_centers_finance/features/auth/domain/usecases/auth_usecases.dart';
import 'package:quran_centers_finance/features/auth/presentation/bloc/auth_bloc.dart';

class _MockObserveAuthProfile extends Mock implements ObserveAuthProfile {}

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignInWithGoogleUseCase extends Mock
    implements SignInWithGoogleUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _FakeUserProfile extends Fake implements UserProfileEntity {}

UserProfileEntity _profile({bool isActive = true}) => UserProfileEntity(
      id: 'uid-1',
      name: 'محمد أحمد',
      email: 'admin@example.com',
      role: 'admin',
      financialPermissions: const FinancialPermissions.all(),
      isActive: isActive,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserProfile());
  });

  late _MockObserveAuthProfile observeProfile;
  late _MockSignInUseCase signInUseCase;
  late _MockSignInWithGoogleUseCase signInWithGoogleUseCase;
  late _MockSignOutUseCase signOutUseCase;

  setUp(() {
    observeProfile = _MockObserveAuthProfile();
    signInUseCase = _MockSignInUseCase();
    signInWithGoogleUseCase = _MockSignInWithGoogleUseCase();
    signOutUseCase = _MockSignOutUseCase();
  });

  AuthBloc buildBloc() => AuthBloc(
        observeAuthProfile: observeProfile,
        signIn: signInUseCase,
        signInWithGoogle: signInWithGoogleUseCase,
        signOut: signOutUseCase,
      );

  test('FinancialPermissions الافتراضية والكاملة تعمل', () {
    expect(const FinancialPermissions.none().create, isFalse);
    expect(const FinancialPermissions.all().create, isTrue);
    expect(_profile().isAdmin, isTrue);
    expect(_profile(isActive: false).isActive, isFalse);
  });

  blocTest<AuthBloc, AuthState>(
    'يبث غير مصادق عندما يكون بث الملف الشخصي فارغًا',
    build: () {
      when(() => observeProfile.call())
          .thenAnswer((_) => Stream<UserProfileEntity?>.value(null));
      return buildBloc();
    },
    expect: () => <Matcher>[
      isA<AuthUnauthenticated>(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'يبث مصادقًا عند وصول ملف موثوق نشط',
    build: () {
      when(() => observeProfile.call())
          .thenAnswer((_) => Stream<UserProfileEntity?>.value(_profile()));
      return buildBloc();
    },
    expect: () => <Matcher>[
      isA<AuthAuthenticated>(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'يعامل الحساب المعطل كغير مصادق',
    build: () {
      when(() => observeProfile.call()).thenAnswer(
        (_) => Stream<UserProfileEntity?>.value(_profile(isActive: false)),
      );
      return buildBloc();
    },
    expect: () => <Matcher>[
      isA<AuthUnauthenticated>(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'فشل تسجيل الدخول ينتج حالة فشل برسالة عربية',
    build: () {
      when(() => observeProfile.call())
          .thenAnswer((_) => const Stream<UserProfileEntity?>.empty());
      when(() => signInUseCase.call(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => const Left(OperationRejectedFailure(
          'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        )),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthSignInRequested(
      email: 'admin@example.com',
      password: 'wrong-password',
    )),
    expect: () => <Matcher>[
      isA<AuthLoading>(),
      isA<AuthFailure>().having(
        (s) => s.message,
        'message',
        'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      ),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'نجاح تسجيل الدخول ينتج حالة مصادقة',
    build: () {
      when(() => observeProfile.call())
          .thenAnswer((_) => const Stream<UserProfileEntity?>.empty());
      when(() => signInUseCase.call(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => Right(_profile()));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthSignInRequested(
      email: 'admin@example.com',
      password: 'correct-password',
    )),
    expect: () => <Matcher>[
      isA<AuthLoading>(),
      isA<AuthAuthenticated>(),
    ],
  );
}
