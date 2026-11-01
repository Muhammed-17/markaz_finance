import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/data/models/pending_operation_model.dart';
import 'package:quran_centers_finance/core/errors/exceptions.dart';
import 'package:quran_centers_finance/core/errors/failures.dart';
import 'package:quran_centers_finance/core/services/pending_operations_service.dart';

void main() {
  group('PendingOperationsService.isTransientFailure', () {
    test('أعطال الشبكة/الازدحام عابرة', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'resource-exhausted',
      ]) {
        expect(
          PendingOperationsService.isTransientFailure(
            ServerException('x', code: code),
          ),
          isTrue,
          reason: code,
        );
      }
    });

    test('الرفض النهائي والتحقق ليسا عابرين', () {
      expect(
        PendingOperationsService.isTransientFailure(
          const ServerException('x', code: 'permission-denied'),
        ),
        isFalse,
      );
      expect(
        PendingOperationsService.isTransientFailure(
          const ValidationException('رصيد غير كافٍ'),
        ),
        isFalse,
      );
      expect(PendingOperationsService.isTransientFailure(Exception('x')), isFalse);
    });
  });

  group('PendingOperationsService.isTransientFailureModel', () {
    test('NetworkFailure وأكواد الخادم العابرة عابرة', () {
      expect(
        PendingOperationsService.isTransientFailureModel(const NetworkFailure()),
        isTrue,
      );
      expect(
        PendingOperationsService.isTransientFailureModel(
          const ServerFailure('x', code: 'deadline-exceeded'),
        ),
        isTrue,
      );
    });

    test('الصلاحيات والرفض النهائي ليسا عابرين', () {
      expect(
        PendingOperationsService.isTransientFailureModel(
          const PermissionFailure('x'),
        ),
        isFalse,
      );
      expect(
        PendingOperationsService.isTransientFailureModel(
          const ServerFailure('x', code: 'permission-denied'),
        ),
        isFalse,
      );
    });
  });

  group('PendingOperationsService.sumAmount', () {
    PendingOperationModel op(Map<String, dynamic> payload) =>
        PendingOperationModel(
          id: payload.hashCode.toString(),
          ownerUid: 'u',
          type: 'repayLoan',
          title: 't',
          payload: payload,
          createdAt: DateTime(2026),
        );

    test('يجمع المبالغ ويعدّ المفقود صفرًا', () {
      expect(
        PendingOperationsService.sumAmount([
          op({'amount': 100}),
          op({'amount': 50.5}),
          op({'loanId': 'x'}),
        ]),
        150.5,
      );
      expect(PendingOperationsService.sumAmount(const []), 0);
    });
  });
}
