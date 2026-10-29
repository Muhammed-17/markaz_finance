# نظام إدارة الشؤون المالية والإدارية لمراكز تحفيظ القرآن الكريم

تطبيق Flutter متكامل لإدارة المراكز والفروع والمستخدمين والأظرف المالية والحركات النقدية وسلف الموظفين وسدادها والتقارير — وفق معمارية نظيفة (Clean Architecture) وإدارة حالة BLoC، مع تنفيذ كل العمليات المالية الحساسة عبر **معاملات Firestore الذرية + قواعد أمان صارمة** — **بدون Cloud Functions وبالخطة المجانية بالكامل (Spark)**.

---

## 1) نظرة عامة

| البند | القيمة |
|---|---|
| الواجهة | Flutter (عربية RTL بالكامل، خط Cairo) |
| الحالة | flutter_bloc (Bloc/Cubit) + bloc_concurrency |
| البنية | Clean Architecture (Presentation / Domain / Data / Core) |
| الهوية | Firebase Auth + Cloud Firestore + Storage + App Check |
| العمليات المالية | معاملات Firestore الذرية `runTransaction` + قواعد أمان Firestore (بديل مجاني كامل لـ Cloud Functions) |
| التخزين المحلي | Hive (كاش عرض ومسودات فقط — ليس مصدرًا للأرصدة أو الصلاحيات) |
| التنقل | GoRouter مع حواجز حماية مركزية |
| العملة | الجنيه المصري — أرقام عادية بمنزلتين عشريتين، بلا حقل currency |

### المبادئ المالية المقيدة (مطابقة للمواصفة)

1. خزنة نقدية واحدة فقط — لا توجد مجموعة `treasury`.
2. مجموعة `transactions` هي السجل النقدي الفعلي، و`fundEnvelopes` تقسيم تنظيمي وليست خزائن.
3. `envelopeTransactions` لا تُجمع مع `transactions` عند حساب الإيرادات/المصروفات.
4. كل عملية مالية تمر من `FinancialOperationsService`: تحقق كامل قبل الكتابة (هوية + صلاحيات من مستند users الموثوق + قيم مسموحة + كفاية الرصيد + توافق الظرف المخصص + منع التكرار)، ثم تنفيذ ذري (حركة + حركة ظرف + رصيد + سجل تدقيق معًا أو لا شيء)، وتحرسها قواعد أمان Firestore على الخادم دائمًا.
5. سداد السلف مقيد بـ `requestId` فريد لمنع التكرار (تحقق ذري داخل المعاملة).
6. إلغاء الحركات المرتبطة بالسلف ممنوع من المسار العام لحماية سلامة أرصدة السلف (سياسة موثقة أدناه).
7. الحسابات المالية في العميل تجري بأعداد صحيحة من القروش (1 ج.م = 100 قرش) عبر صنف `Money` لتفادي أخطاء الفاصلة العائمة.

### كيف يعمل النظام بدون Cloud Functions (مجاني)؟

ثلاث طبقات حماية تحل محل الخادم السابق:

1. **التحقق الكامل قبل الكتابة** — `lib/core/services/financial_operations_service.dart` ينفذ العمليات العشر بنفس منطق الخادم حرفيًا (نفس القواعد ونفس الرسائل العربية)، ويقرأ الصلاحيات من مستند `users/{uid}` الموثوق لا من حالة العميل.
2. **ذرية المعاملات** — كل عملية تُنفَّذ داخل `runTransaction` (حتى 5 محاولات تلقائية عند التعارض): لا حالة وسيطة ولا حركات يتيمة أبدًا.
3. **قواعد أمان Firestore** — `firestore.rules` تُنفَّذ على خوادم Firebase حتى لو خُرق تطبيق العميل: حقول كل مجموعة مقفلة بالاسم والنوع، الرصيد لا يقبل سالبًا، كل حركة نقدية/ظرف **مقرونة إلزاميًا بتغيّر رصيد الظرف بنفس الأثر في نفس الدفعة** (getAfter)، سجلات التدقيق إنشاء فقط، الإلغاء مسار واحد مضبوط، وتعديل الذات للصلاحيات ممنوع.

---

## 2) هيكل المشروع

```text
├── assets/fonts/cairo/            خط Cairo (متغير)
├── firestore.rules                قواعد الأمان الصارمة (خط الدفاع الخادمي)
├── firestore.indexes.json         الفهارس المركبة المطلوبة
├── storage.rules                  مرفقات الحركات (صور/PDF ≤ 10MB)
├── firebase.json
└── lib/
    ├── main.dart / bootstrap.dart
    ├── firebase_options.dart      ⚠️ placeholder — يُستبدل عبر flutterfire configure
    ├── app/                       app, router+guards, DI (get_it)
    ├── core/
    │   ├── constants/             app_colors, app_dimensions, app_durations, app_constants
    │   ├── theme/                 app_theme, app_typography
    │   ├── errors/                failures, exceptions, error_handler
    │   ├── network/               connectivity_service
    │   ├── utils/                 money, validators, formatters, date_time_utils
    │   ├── services/              firebase, hive, permission_service,
    │   │                          financial_operations_service (العمليات المالية العشر ذريًا),
    │   │                          financial_validators (مدققون مطابقون لقواعد الأمان)
    │   ├── domain/entities/       كيانات مشتركة (user, transaction, envelope, loans, logs…)
    │   ├── data/models/           نماذج Firestore المطابقة حرفيًا للتصميم
    │   └── widgets/               مكتبة ودجات موحدة (أزرار/حقول/بطاقات/حوارات/شل)
    ├── l10n/                      النصوص العربية المركزية
    └── features/                  عشر ميزات × (data/domain/presentation/di + routes)
        auth, dashboard, centers, branches, users,
        envelopes, transactions, employee_loans, reports, settings
```

---

## 3) خطوات الإعداد والتشغيل (بلا خطة مدفوعة)

### المتطلبات
- Flutter SDK 3.24+ وDart 3.5+ وAndroid Studio/Xcode حسب المنصات
- Firebase CLI: `npm install -g firebase-tools` (لنشر القواعد والفهارس فقط)
- flutterfire CLI: `dart pub global activate flutterfire_cli`
- **مشروع Firebase على الخطة المجانية Spark — لا حاجة لرفع حساب فوترة إطلاقًا**

### الخطوات

```bash
# 1) توليد مجلدات المنصات داخل المشروع
flutter create . --platforms android,ios,web --org org.qurancenters --project-name quran_centers_finance

# 2) ربط مشروع Firebase وتوليد firebase_options.dart (يستبدل الـ placeholder تلقائيًا)
firebase login
flutterfire configure
#   اختر مشروعك والمنصات المطلوبة، وفعّل Authentication (Email/Password).

# 3) حزم Flutter
flutter pub get

# 4) النشر: قواعد الأمان + الفهارس فقط (لا دوال سحابية)
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### إنشاء أول مدير (Bootstrap)

أول حساب يُنشأ يدويًا من Firebase Console لأن قواعد الأمان تمنع إنشاء مستخدمين قبل وجود مدير:

1. Firebase Console → Authentication → Add user (البريد وكلمة مرور قوية).
2. انسخ **UID** ثم أنشئ مستندًا في Firestore:
   - المجموعة: `users`، معرّف المستند: **UID**،
3. الحقول:

```json
{
  "name": "مدير النظام",
  "email": "admin@example.com",
  "role": "admin",
  "financialPermissions": {
    "create": true, "update": true, "cancel": true, "approve": true
  },
  "isActive": true
}
```

4. سجّل الدخول من التطبيق، ثم أنشئ باقي المستخدمين من شاشة «المستخدمون» — ينشئ التطبيق حساب المصادقة عبر **نسخة Firebase ثانوية** (بدون التأثير على جلستك) ثم يكتب مستند users بصلاحياتك الإدارية. ملاحظة: يتطلب هذا تفعيل مزود Email/Password (مفعّل بالفعل لتسجيل الدخول).

### App Check
مفعّل في `lib/core/services/firebase_service.dart`. في التطوير يعمل بمزود `debug` تلقائيًا (`kDebugMode`)؛ في الإنتاج: `playIntegrity` لأندرويد و`deviceCheck` لآبل — سجّل تطبيقاتك في Firebase Console → App Check. للويب بدّل `WebProvider.debug` إلى reCaptcha Enterprise مع مفتاح موقعك.

### الاختبارات
```bash
flutter test
```
تغطي: دقة `Money` بالقروش، المدققات (المبالغ/الشهر/الإلغاء)، التنسيقات، وBLoC المصادقة عبر محاكاة المستودع.

---

## 4) تصميم Firestore (المجموعات العشر فقط)

| المجموعة | الوصف | مسار الكتابة |
|---|---|---|
| `centers/{id}` | name, description, createdAt, updatedAt | مدير فقط (مقيد بالقواعد) |
| `branches/{id}` | centerId, name, location, createdAt, updatedAt | مدير فقط (مقيد بالقواعد) |
| `users/{uid}` | name, email, role, financialPermissions, isActive | مدير approve — قواعد تمنع تعديل الذات الحساس |
| `fundEnvelopes/{id}` | name, purpose, fundType, allowedExpenseCategories, currentBalance, centerId, status, createdAt | إنشاء/وصفي: update — الرصيد: معاملة ذرية فقط |
| `transactions/{id}` | السجل النقدي الفعلي (13 حقلًا معتمدًا حرفيًا) | معاملة ذرية + اقتران إلزامي برصيد الظرف |
| `envelopeTransactions/{id}` | تغيرات أرصدة الأظرف فقط | معاملة ذرية + اقتران إلزامي بالرصيد |
| `transactionLogs/{id}` | تدقيق الحركات (CREATE/UPDATE/CANCEL) | إنشاء ضمن المعاملة — لا تعديل/حذف أبدًا |
| `employeeLoans/{id}` | السلف (employeeId?, employeeName, totalAmount, remainingBalance, status, notes, version) | معاملة ذرية — المتبقي لا يزيد أبدًا |
| `loanPayments/{id}` | المدفوعات (loanId, paidAmount, paymentDate, transactionId, requestId, notes) | معاملة ذرية — requestId إلزامي |
| `loanLogs/{id}` | تدقيق السلف (CREATE/UPDATE/PAYMENT/PAYOFF) | إنشاء ضمن المعاملة — لا تعديل/حذف أبدًا |

لا حقل `currency`، لا `branchId` في المراكز، لا `centerId/branchId` في السلف، لا حقول زمنية غير معتمدة، ولا مجموعات محذوفة (`settings/finance`, `donations`, `userLogs`).

### المعادلة المالية
```
الرصيد النقدي = الافتتاحي (opening_balance) + الإيرادات التشغيلية − المصروفات الفعلية
              (الحركات النشطة فقط؛ الملغاة مستبعدة؛ التحويلات بين الأظرف محايدة)
```

---

## 5) سياسات مالية موثقة (قرارات مقصودة)

1. **إلغاء حركات السلف**: يُرفض إلغاء أي حركة تحمل `employeeLoanId` (صرف أو سداد) لأن `loanLogs` لا يعرّف إجراء حذف — الحماية (في الخدمة والقواعد معًا) تمنع فساد أرصدة السلف. لأي تصحيح جوهري: عدّل عبر سجل سداد/صرف جديد وفق سياسة النظام.
2. **تصنيفات محجوزة**: `employee_loan` و`loan_repayment` لا تقبلها العملية العامة `createTransaction` — تُنشأ حصريًا عبر عمليتي السلف لضمان تحديث `remainingBalance` والحالات (قيد مفعّل في الخدمة وفي قواعد الأمان).
3. **أرشفة الأظرف**: لا حذف نهائي؛ يُرفض أرشفة ظرف برصيد غير صفري (حوّل الرصيد أولًا). الظرف المؤرشف يمنع الصرف، ويمكن تعديل بياناته الوصفية وإعادة تنشيطه.
4. **عدم التكرار**: سداد السلف يتحقق من `requestId` داخل المعاملة الذرية؛ باقي العمليات ذرية عبر `runTransaction` مع إعادة قراءة الرصيد داخل المعاملة وإعادة محاولة تلقائية عند التعارض.
5. **تعديل الذات ممنوع**: لا يمكن لأي مدير تعديل دوره أو صلاحياته أو تعطيل حسابه بنفسه (حماية في الخدمة وفي قواعد الأمان).
6. **الرصيد الافتتاحي للظرف**: عند إنشاء ظرف برصيد مبدئي > 0، تُنشأ حركة `opening_balance` + تخصيص `allocation` في نفس المعاملة؛ لذا يدخل الرصيد النقدي دون أن يُحسب إيرادًا تشغيليًا.
7. **عرض النجاح**: لا تُعرض رسالة نجاح مالية إلا بعد تأكيد إتمام المعاملة؛ عند الفشل تُحفظ مسودة محلية (Hive) تلقائيًا.

### حدود نموذج الخطة المجانية (يجب فهمها)

- **سجلات التدقيق**: تُنشأ ضمن نفس المعاملة المالية لكن بواسطة العميل المخوّل — مستخدم مخوّل نظريًا قد يزوّر سجلًا (لا توقيع خادمي). القواعد تمنع التعديل والحذف بعد الإنشاء.
- **رصيد الظرف**: تحديث `currentBalance` وحده مسموح فقط لصاحب صلاحية `create`/`cancel` ضمن قيود رقمية صارمة، لكن القواعد لا تستطيع إثبات اقترانه بحركة ظرف إن كتبه طرف مخوّل خارج التطبيق. **التخفيف**: أبقِ صلاحية `create` للموثوقين فقط، وراجع دوريًا تطابق مجموع `envelopeTransactions` مع `currentBalance` لكل ظرف (أي انحراف يظهر فورًا في شاشة حركات الظرف).
- **إنشاء المستخدمين**: يعتمد على مزود Email/Password المفعّل؛ أي شخص يملك التطبيق يستطيع نظريًا إنشاء حساب مصادقة فارغ، لكنه يرى **لا شيء** بدون مستند `users` (القواعد ترفض كل شيء)، ويمكنك من Console حذف أي حسابات دخيل.
- لو انتقلت لاحقًا لخطة Blaze: المنطق نفسه قابل للنقل إلى Cloud Functions كما هو (العقد `call(operation, data)` جاهز لذلك).

---

## 6) الفهارس المطلوبة
مضمّنة في `firestore.indexes.json` وتُنشر تلقائيًا بأمر deploy أعلاه (15 فهرسًا مركبًا تغطي فلاتر القوائم والتقارير وسجلات التدقيق). أي استعلام جديد يجب أن يلتزم بأنماط الفهارس الموجودة.

## 7) ملاحظات للمطورين
- معرفات العمليات المالية موحدة في `AppFunctions` (Dart) وتُمرر إلى `FinancialOperationsService.call()` — أضف أي عملية جديدة هناك وبقواعد الأمان معًا.
- المدققون في `financial_validators.dart` هي المرآة التنفيذية لقواعد `firestore.rules` — أي تغيير في قاعدة يجب أن ينعكس في المدقق المقابل والعكس.
- قواعد المعمارية يفحصها سكربت: `python3 scripts/validate_dart_imports.py` (استيرادات + جزئيات part + نقاء domain + منع الأنماط المحظورة).
- الحساسية المالية: أي منطق رصيد/صلاحية جديد يجب أن يضاف إلى `FinancialOperationsService` (تحقق قبل الكتابة) وإلى `firestore.rules` (إنفاذ خادمي)، ثم في `PermissionService` للعرض فقط.
