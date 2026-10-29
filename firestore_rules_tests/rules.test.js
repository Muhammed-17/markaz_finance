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

    // مستخدم بصلاحية مالية كاملة
    await adminDb.doc('users/user_creator').set({
      name: 'محاسب المركز',
      role: 'user',
      isActive: true,
      financialPermissions: { create: true, cancel: true, approve: false, update: false },
    });

    // مستخدم بصلاحية approve فقط
    await adminDb.doc('users/user_approver').set({
      name: 'مشرف القبول',
      role: 'user',
      isActive: true,
      financialPermissions: { create: false, cancel: false, approve: true, update: false },
    });

    // مستخدم admin
    await adminDb.doc('users/user_admin').set({
      name: 'المدير',
      role: 'admin',
      isActive: true,
      financialPermissions: { create: false, cancel: false, approve: false, update: false },
    });

    // مستخدم بدون صلاحية
    await adminDb.doc('users/user_unauthorized').set({
      name: 'مستخدم عادي',
      role: 'user',
      isActive: true,
      financialPermissions: { create: false, cancel: false, approve: false, update: false },
    });

    // مركز وظرفان نشطان
    await adminDb.doc('centers/center_1').set({ name: 'المركز الرئيسي' });

    await adminDb.doc('fundEnvelopes/env_1').set({
      name: 'الظرف العام',
      currentBalance: 1000,
      fundType: 'general',
      status: 'active',
      lastEnvTxId: 'tx_init',
    });

    await adminDb.doc('fundEnvelopes/env_2').set({
      name: 'الظرف الثاني',
      currentBalance: 500,
      fundType: 'general',
      status: 'active',
      lastEnvTxId: 'tx_init_2',
    });

    if (customSetup) {
      await customSetup(adminDb);
    }
  });
}

// =====================================================================
// 1. حركات الأظرف الأساسية — العمليات الصحيحة والفاشلة
// =====================================================================
describe('1. حركات الأظرف الأساسية', () => {
  test('نجاح: إنشاء حركة مصروف مقترنة بحركة ظرف وخصم الرصيد', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    batch.set(clientDb.doc('transactions/txn_exp_1'), {
      centerId: 'center_1', branchId: null, envelopeId: 'env_1',
      type: 'expense', category: 'salaries', name: 'صرف راتب',
      amount: 200, paymentMethod: 'cash', forMonth: '2026-10',
      status: 'active', employeeLoanId: null, attachmentPaths: [],
      notes: 'راتب شهر 10', createdAt: new Date(),
    });
    batch.set(clientDb.doc('envelopeTransactions/env_tx_1'), {
      envelopeId: 'env_1', transactionId: 'txn_exp_1',
      type: 'expense', amount: 200, notes: 'صرف راتب',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 800, lastEnvTxId: 'env_tx_1',
    });

    await assertSucceeds(batch.commit());
  });

  test('فشل: مستخدم بدون صلاحية create لا ينشئ حركة مالية', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_unauthorized').firestore();

    await assertFails(
      clientDb.doc('transactions/txn_unauth').set({
        centerId: 'center_1', branchId: null, envelopeId: 'env_1',
        type: 'income', category: 'donation', name: 'تبرع',
        amount: 100, paymentMethod: 'cash', forMonth: null,
        status: 'active', employeeLoanId: null, attachmentPaths: [],
        notes: '', createdAt: new Date(),
      })
    );
  });

  test('فشل: مستخدم غير مسجل لا يقرأ أي شيء', async () => {
    await setupBaseData();
    const clientDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(clientDb.doc('transactions/any').get());
  });

  test('نجاح: المستخدم النشط يقرأ الحركات حتى بدون صلاحيات تنفيذ', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_unauthorized').firestore();
    await assertSucceeds(clientDb.doc('transactions/any').get());
  });
});

// =====================================================================
// 2. هجمات إعادة الاستخدام (Replay Attacks)
// =====================================================================
describe('2. هجمات إعادة الاستخدام (Replay Attacks)', () => {
  test('فشل: إعادة استخدام حركة نقدية قديمة لرفع رصيد الظرف', async () => {
    await setupBaseData(async (adminDb) => {
      await adminDb.doc('transactions/txn_old').set({
        centerId: 'center_1', branchId: null, envelopeId: 'env_1',
        type: 'income', category: 'donation', name: 'تبرع قديم',
        amount: 500, paymentMethod: 'cash', forMonth: null,
        status: 'active', employeeLoanId: null, attachmentPaths: [], notes: '',
        createdAt: new Date(),
      });
    });

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    batch.set(clientDb.doc('envelopeTransactions/env_tx_replay'), {
      envelopeId: 'env_1', transactionId: 'txn_old',
      type: 'income', amount: 500, notes: 'إعادة تدوير',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 1500, lastEnvTxId: 'env_tx_replay',
    });

    await assertFails(batch.commit());
  });

  test('فشل: إلغاء حركة ملغاة مسبقاً (double cancel)', async () => {
    await setupBaseData(async (adminDb) => {
      // حركة نقدية موجودة بحالة ملغاة بالفعل
      await adminDb.doc('transactions/txn_already_cancelled').set({
        centerId: 'center_1', branchId: null, envelopeId: 'env_1',
        type: 'expense', category: 'salaries', name: 'راتب ملغى',
        amount: 300, paymentMethod: 'cash', forMonth: null,
        status: 'cancelled', employeeLoanId: null, attachmentPaths: [], notes: '',
        createdAt: new Date(),
      });
    });

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    // محاولة إنشاء refund اعتماداً على حركة ملغاة مسبقاً
    batch.set(clientDb.doc('envelopeTransactions/env_tx_double_cancel'), {
      envelopeId: 'env_1', transactionId: 'txn_already_cancelled',
      type: 'refund', amount: 300, notes: 'إلغاء مكرر',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 1300, lastEnvTxId: 'env_tx_double_cancel',
    });

    // يجب أن تفشل: get(txnPath).data.status != 'active' (هو cancelled)
    await assertFails(batch.commit());
  });

  test('فشل: إعادة استخدام lastPaymentId قديم لإنقاص رصيد سلفة بلا سداد', async () => {
    await setupBaseData(async (adminDb) => {
      await adminDb.doc('employeeLoans/loan_active').set({
        employeeId: null, employeeName: 'محمود حسن',
        totalAmount: 1000, remainingBalance: 800, status: 'active',
        notes: '', version: 1, disbursementTxnId: 'txn_prev',
      });
      await adminDb.doc('loanPayments/pay_old').set({
        loanId: 'loan_active', paidAmount: 200, paymentDate: new Date(),
        transactionId: 'txn_old_pay', requestId: 'pay_old', notes: '',
      });
    });

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    await assertFails(
      clientDb.doc('employeeLoans/loan_active').update({
        remainingBalance: 600, status: 'active', lastPaymentId: 'pay_old',
      })
    );
  });
});

// =====================================================================
// 3. السلف الوهمية واختلاق الدخل
// =====================================================================
describe('3. السلف الوهمية واختلاق الدخل', () => {
  test('فشل: إنشاء سلفة وهمية بدون حركة صرف في نفس الدفعة', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    await assertFails(
      clientDb.doc('employeeLoans/loan_fake').set({
        employeeId: null, employeeName: 'موظف وهمي',
        totalAmount: 1000, remainingBalance: 1000, status: 'active',
        notes: '', version: 1, disbursementTxnId: 'txn_non_existent',
      })
    );
  });

  test('فشل: محاولة سداد سلفة غير موجودة لاختلاق دخل', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    batch.set(clientDb.doc('transactions/txn_fake_repay'), {
      centerId: 'center_1', branchId: null, envelopeId: 'env_1',
      type: 'income', category: 'loan_repayment', name: 'سداد وهمي',
      amount: 500, paymentMethod: 'cash', forMonth: null,
      status: 'active', employeeLoanId: 'non_existent_loan', attachmentPaths: [],
      notes: '', createdAt: new Date(),
    });
    batch.set(clientDb.doc('envelopeTransactions/env_tx_repay'), {
      envelopeId: 'env_1', transactionId: 'txn_fake_repay',
      type: 'income', amount: 500, notes: '',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 1500, lastEnvTxId: 'env_tx_repay',
    });

    await assertFails(batch.commit());
  });

  test('فشل: سداد سلفة بدون إنقاص remainingBalance — سداد بلا خصم', async () => {
    await setupBaseData(async (adminDb) => {
      await adminDb.doc('employeeLoans/loan_1').set({
        employeeId: null, employeeName: 'أحمد علي',
        totalAmount: 1000, remainingBalance: 1000, status: 'active',
        notes: '', version: 1, disbursementTxnId: 'txn_old_disburse',
      });
    });

    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    // المهاجم: ينشئ حركة سداد صحيحة شكلًا لكن لا يُنقص رصيد السلفة
    batch.set(clientDb.doc('transactions/txn_repay_1'), {
      centerId: 'center_1', branchId: null, envelopeId: 'env_1',
      type: 'income', category: 'loan_repayment', name: 'سداد', amount: 200,
      paymentMethod: 'cash', forMonth: null, status: 'active',
      employeeLoanId: 'loan_1', attachmentPaths: [], notes: '', createdAt: new Date(),
    });
    batch.set(clientDb.doc('envelopeTransactions/env_tx_repay_1'), {
      envelopeId: 'env_1', transactionId: 'txn_repay_1',
      type: 'income', amount: 200, notes: '',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    // تحديث رصيد الظرف دون تحديث السلفة — يجب الفشل
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 1200, lastEnvTxId: 'env_tx_repay_1',
    });

    // يجب أن تفشل: القاعدة تشترط getAfter(loan).remainingBalance == get(loan).remainingBalance - amount
    await assertFails(batch.commit());
  });

  test('نجاح: صرف سلفة ذري مكتمل الأطراف', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    batch.set(clientDb.doc('employeeLoans/loan_1'), {
      employeeId: null, employeeName: 'أحمد علي',
      totalAmount: 300, remainingBalance: 300, status: 'active',
      notes: '', version: 1, disbursementTxnId: 'txn_loan_1',
    });
    batch.set(clientDb.doc('transactions/txn_loan_1'), {
      centerId: 'center_1', branchId: null, envelopeId: 'env_1',
      type: 'expense', category: 'employee_loan', name: 'سلفة: أحمد علي',
      amount: 300, paymentMethod: 'cash', forMonth: null,
      status: 'active', employeeLoanId: 'loan_1', attachmentPaths: [],
      notes: '', createdAt: new Date(),
    });
    batch.set(clientDb.doc('envelopeTransactions/env_tx_loan_1'), {
      envelopeId: 'env_1', transactionId: 'txn_loan_1',
      type: 'expense', amount: 300, notes: '',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 700, lastEnvTxId: 'env_tx_loan_1',
    });

    await assertSucceeds(batch.commit());
  });
});

// =====================================================================
// 4. التحويل بين الأظرف — اقتران _out و _in
// =====================================================================
describe('4. التحويل بين الأظرف', () => {
  test('نجاح: تحويل صحيح بمعرفات حتمية _out و _in', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();
    const transferId = 'tr_abc123';

    batch.set(clientDb.doc(`envelopeTransactions/${transferId}_out`), {
      envelopeId: 'env_1', transactionId: null,
      type: 'transfer_out', amount: 200, notes: 'تحويل اختبار',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.set(clientDb.doc(`envelopeTransactions/${transferId}_in`), {
      envelopeId: 'env_2', transactionId: null,
      type: 'transfer_in', amount: 200, notes: 'تحويل اختبار',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 800, lastEnvTxId: `${transferId}_out`,
    });
    batch.update(clientDb.doc('fundEnvelopes/env_2'), {
      currentBalance: 700, lastEnvTxId: `${transferId}_in`,
    });

    await assertSucceeds(batch.commit());
  });

  test('فشل: نصف تحويل — _out بدون _in المقابلة', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();

    batch.set(clientDb.doc('envelopeTransactions/tr_half_out'), {
      envelopeId: 'env_1', transactionId: null,
      type: 'transfer_out', amount: 100, notes: 'نصف تحويل',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.update(clientDb.doc('fundEnvelopes/env_1'), {
      currentBalance: 900, lastEnvTxId: 'tr_half_out',
    });

    // يجب أن تفشل: لا يوجد _in مقابل
    await assertFails(batch.commit());
  });

  test('فشل: تحويل لنفس الظرف (env_1 → env_1)', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_creator').firestore();
    const batch = clientDb.batch();
    const transferId = 'tr_self';

    batch.set(clientDb.doc(`envelopeTransactions/${transferId}_out`), {
      envelopeId: 'env_1', transactionId: null,
      type: 'transfer_out', amount: 100, notes: '',
      createdBy: 'user_creator', createdAt: new Date(),
    });
    batch.set(clientDb.doc(`envelopeTransactions/${transferId}_in`), {
      envelopeId: 'env_1', transactionId: null, // نفس الظرف!
      type: 'transfer_in', amount: 100, notes: '',
      createdBy: 'user_creator', createdAt: new Date(),
    });

    // يجب أن تفشل: القاعدة تشترط envelopeId != d.envelopeId بين الطرفين
    await assertFails(batch.commit());
  });
});

// =====================================================================
// 5. صلاحيات المستخدمين والتصعيد (Role Escalation)
// =====================================================================
describe('5. صلاحيات المستخدمين والتصعيد', () => {
  test('فشل: صاحب approve لا يستطيع رفع مستخدم إلى admin', async () => {
    await setupBaseData(async (adminDb) => {
      await adminDb.doc('users/target_user').set({
        name: 'مستخدم هدف', role: 'user', isActive: true,
        email: 'target@test.com',
        financialPermissions: { create: false, cancel: false, approve: false, update: false },
      });
    });

    const clientDb = testEnv.authenticatedContext('user_approver').firestore();
    await assertFails(
      clientDb.doc('users/target_user').update({ role: 'admin' })
    );
  });

  test('فشل: صاحب approve لا يستطيع تعطيل مدير (isActive = false)', async () => {
    const clientDb = testEnv.authenticatedContext('user_approver').firestore();
    // user_admin دوره 'admin' — القاعدة تمنع تعديله من approve
    await setupBaseData();
    await assertFails(
      clientDb.doc('users/user_admin').update({ isActive: false })
    );
  });

  test('فشل: مستخدم لا يستطيع تعديل صلاحياته بنفسه', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_unauthorized').firestore();
    await assertFails(
      clientDb.doc('users/user_unauthorized').update({
        financialPermissions: { create: true, cancel: true, approve: true, update: true },
      })
    );
  });

  test('نجاح: المدير يستطيع رفع مستخدم إلى admin', async () => {
    await setupBaseData(async (adminDb) => {
      await adminDb.doc('users/target_user').set({
        name: 'مستخدم هدف', role: 'user', isActive: true,
        email: 'target@test.com',
        financialPermissions: { create: false, cancel: false, approve: false, update: false },
      });
    });

    const clientDb = testEnv.authenticatedContext('user_admin').firestore();
    await assertSucceeds(
      clientDb.doc('users/target_user').update({ role: 'admin' })
    );
  });

  test('فشل: المدير لا يستطيع تغيير دوره بنفسه', async () => {
    await setupBaseData();
    const clientDb = testEnv.authenticatedContext('user_admin').firestore();
    // القاعدة: isAdmin && (uid != userId || onlyKeys(['name']))
    await assertFails(
      clientDb.doc('users/user_admin').update({ role: 'user' })
    );
  });
});
