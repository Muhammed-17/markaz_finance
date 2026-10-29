const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

let testEnv;

beforeAll(async () => {
  const rules = fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-rules-test',
    firestore: {
      rules: rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
  }
});

// تهيئة بيانات الاختبار عبر سياق معطل القواعد (withSecurityRulesDisabled)
async function setupBaseData(customSetup) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();

    // 1. مستخدم بصلاحية مالية كاملة
    await adminDb.doc('users/user_creator').set({
      name: 'محاسب المركز',
      role: 'user',
      isActive: true,
      financialPermissions: {
        create: true,
        view: true,
        cancel: true,
      },
    });

    // 2. مستخدم بدون صلاحية
    await adminDb.doc('users/user_unauthorized').set({
      name: 'مستخدم عادي',
      role: 'user',
      isActive: true,
      financialPermissions: {
        create: false,
        view: false,
        cancel: false,
      },
    });

    // 3. مركز وظرف نشط
    await adminDb.doc('centers/center_1').set({
      name: 'المركز الرئيسي',
    });

    await adminDb.doc('fundEnvelopes/env_1').set({
      name: 'الظرف العام',
      currentBalance: 1000,
      fundType: 'general',
      status: 'active',
      lastEnvTxId: 'tx_init',
    });

    if (customSetup) {
      await customSetup(adminDb);
    }
  });
}

describe('اختبارات القواعد الأمنية للعمليات المالية - Markaz Finance', () => {
  test('نجاح: إنشاء حركة مصروف مقترنة بحركة ظرف وخصم الرصيد', async () => {
    await setupBaseData();

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    const txnRef = clientDb.doc('transactions/txn_exp_1');
    const envTxRef = clientDb.doc('envelopeTransactions/env_tx_1');
    const envRef = clientDb.doc('fundEnvelopes/env_1');

    batch.set(txnRef, {
      centerId: 'center_1',
      branchId: null,
      envelopeId: 'env_1',
      type: 'expense',
      category: 'salaries',
      name: 'صرف راتب',
      amount: 200,
      paymentMethod: 'cash',
      forMonth: '2026-10',
      status: 'active',
      employeeLoanId: null,
      attachmentPaths: [],
      notes: 'راتب شهر 10',
      createdAt: new Date(),
    });

    batch.set(envTxRef, {
      envelopeId: 'env_1',
      transactionId: 'txn_exp_1',
      type: 'expense',
      amount: 200,
      notes: 'صرف راتب',
      createdBy: 'user_creator',
      createdAt: new Date(),
    });

    batch.update(envRef, {
      currentBalance: 800,
      lastEnvTxId: 'env_tx_1',
    });

    await assertSucceeds(batch.commit());
  });

  test('فشل Replay Attack: محاولة إنشاء حركة ظرف نقدية اعتماداً على حركة نقدية موجودة مسبقاً', async () => {
    await setupBaseData(async (adminDb) => {
      // ننشئ حركة نقدية سابقة
      await adminDb.doc('transactions/txn_old').set({
        centerId: 'center_1',
        branchId: null,
        envelopeId: 'env_1',
        type: 'income',
        category: 'donation',
        name: 'تبرع قديم',
        amount: 500,
        paymentMethod: 'cash',
        forMonth: null,
        status: 'active',
        employeeLoanId: null,
        attachmentPaths: [],
        notes: '',
        createdAt: new Date(),
      });
    });

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    // المهاجم يحاول استخدام txn_old لرفع رصيد الظرف مراراً
    const envTxRef = clientDb.doc('envelopeTransactions/env_tx_replay');
    const envRef = clientDb.doc('fundEnvelopes/env_1');

    batch.set(envTxRef, {
      envelopeId: 'env_1',
      transactionId: 'txn_old',
      type: 'income',
      amount: 500,
      notes: 'إعادة تدوير حركة سابقة',
      createdBy: 'user_creator',
      createdAt: new Date(),
    });

    batch.update(envRef, {
      currentBalance: 1500,
      lastEnvTxId: 'env_tx_replay',
    });

    // يجب أن تفشل المعاملة لأن txn_old كانت موجودة قبل الباتش (!exists فشلت)
    await assertFails(batch.commit());
  });

  test('فشل: محاولة إنشاء سلفة وهمية بدون حركة صرف جديدة في نفس الدفعة', async () => {
    await setupBaseData();

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const loanRef = clientDb.doc('employeeLoans/loan_fake');

    // محاولة إنشاء السلفة منفردة أو بدون حركة صرف نقدية مقترنة
    await assertFails(
      loanRef.set({
        employeeId: null,
        employeeName: 'موظف وهمي',
        totalAmount: 1000,
        remainingBalance: 1000,
        status: 'active',
        notes: 'سلفة وهمية',
        version: 1,
        disbursementTxnId: 'txn_non_existent',
      })
    );
  });

  test('نجاح: صرف سلفة موظف جديدة مقترنة بحركة صرف نقدية وتعديل رصيد الظرف', async () => {
    await setupBaseData();

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    const loanRef = clientDb.doc('employeeLoans/loan_1');
    const txnRef = clientDb.doc('transactions/txn_loan_1');
    const envTxRef = clientDb.doc('envelopeTransactions/env_tx_loan_1');
    const envRef = clientDb.doc('fundEnvelopes/env_1');

    batch.set(loanRef, {
      employeeId: null,
      employeeName: 'أحمد علي',
      totalAmount: 300,
      remainingBalance: 300,
      status: 'active',
      notes: 'سلفة مؤقتة',
      version: 1,
      disbursementTxnId: 'txn_loan_1',
    });

    batch.set(txnRef, {
      centerId: 'center_1',
      branchId: null,
      envelopeId: 'env_1',
      type: 'expense',
      category: 'employee_loan',
      name: 'سلفة للموظف: أحمد علي',
      amount: 300,
      paymentMethod: 'cash',
      forMonth: null,
      status: 'active',
      employeeLoanId: 'loan_1',
      attachmentPaths: [],
      notes: 'سلفة مؤقتة',
      createdAt: new Date(),
    });

    batch.set(envTxRef, {
      envelopeId: 'env_1',
      transactionId: 'txn_loan_1',
      type: 'expense',
      amount: 300,
      notes: 'سلفة مؤقتة',
      createdBy: 'user_creator',
      createdAt: new Date(),
    });

    batch.update(envRef, {
      currentBalance: 700,
      lastEnvTxId: 'env_tx_loan_1',
    });

    await assertSucceeds(batch.commit());
  });

  test('فشل: محاولة سداد سلفة وهمية أو غير موجودة لاختلاق دخل في الظرف', async () => {
    await setupBaseData();

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    const txnRef = clientDb.doc('transactions/txn_fake_repay');
    const envTxRef = clientDb.doc('envelopeTransactions/env_tx_repay');
    const envRef = clientDb.doc('fundEnvelopes/env_1');

    batch.set(txnRef, {
      centerId: 'center_1',
      branchId: null,
      envelopeId: 'env_1',
      type: 'income',
      category: 'loan_repayment',
      name: 'سداد سلفة وهمية',
      amount: 500,
      paymentMethod: 'cash',
      forMonth: null,
      status: 'active',
      employeeLoanId: 'non_existent_loan',
      attachmentPaths: [],
      notes: '',
      createdAt: new Date(),
    });

    batch.set(envTxRef, {
      envelopeId: 'env_1',
      transactionId: 'txn_fake_repay',
      type: 'income',
      amount: 500,
      notes: '',
      createdBy: 'user_creator',
      createdAt: new Date(),
    });

    batch.update(envRef, {
      currentBalance: 1500,
      lastEnvTxId: 'env_tx_repay',
    });

    // يجب أن تفشل الحركة لأن employeeLoanId غير موجود في employeeLoans
    await assertFails(batch.commit());
  });

  test('فشل Replay Attack: محاولة إنقاص دين السلفة باستخدام lastPaymentId قديم', async () => {
    await setupBaseData(async (adminDb) => {
      // سلفة موجودة
      await adminDb.doc('employeeLoans/loan_active').set({
        employeeId: null,
        employeeName: 'محمود حسن',
        totalAmount: 1000,
        remainingBalance: 800,
        status: 'active',
        notes: '',
        version: 1,
        disbursementTxnId: 'txn_prev',
      });

      // قسط سداد قديم تم مسبقاً
      await adminDb.doc('loanPayments/pay_old').set({
        loanId: 'loan_active',
        paidAmount: 200,
        paymentDate: new Date(),
        transactionId: 'txn_old_pay',
        requestId: 'pay_old',
        notes: '',
      });
    });

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const loanRef = clientDb.doc('employeeLoans/loan_active');

    // محاولة إنقاص الرصيد إلى 600 وإعادة تمرير lastPaymentId = 'pay_old'
    await assertFails(
      loanRef.update({
        remainingBalance: 600,
        status: 'active',
        lastPaymentId: 'pay_old',
      })
    );
  });
});
