/// تمثيل المبالغ المالية بدقة منزلتين عشريتين باستخدام عدد صحيح من القروش
/// (1 جنيه = 100 قرش) لتفادي أخطاء الجمع العائم.
///
/// المصدر النهائي للأرصدة هو Firestore، وهذا الصنف يضمن دقة الحساب في العميل فقط.
class Money implements Comparable<Money> {
  const Money(this.piasters) : assert(piasters >= 0);

  /// القيمة صفر.
  static const Money zero = Money(0);

  /// أقصى مبلغ مسموح (مليار جنيه) كحد أمان.
  static const int maxPiasters = 100000000000;

  final int piasters;

  /// الإنشاء من رقم عادي بالجنيه مثل 1250.50 (يقرّب لأقرب قرش).
  factory Money.fromUnits(num units) {
    if (units.isNaN || units.isInfinite) {
      throw ArgumentError('قيمة مالية غير صالحة');
    }
    if (units < 0) throw ArgumentError('المبلغ لا يمكن أن يكون سالبًا');
    final pi = (units * 100).round();
    if (pi > maxPiasters) throw ArgumentError('المبلغ يتجاوز الحد الأقصى المسموح');
    return Money(pi);
  }

  /// التحقق من أن المبلغ لا يحوي أكثر من منزلتين عشريتين.
  static bool hasValidPrecision(num units) {
    final scaled = units * 100;
    return (scaled - scaled.roundToDouble()).abs() < 1e-6;
  }

  /// القيمة كرقم جنيهات عادي (للتخزين في Firestore).
  double get asDouble => piasters / 100.0;

  bool get isZero => piasters == 0;
  bool get isPositive => piasters > 0;

  Money operator +(Money other) => Money(piasters + other.piasters);
  Money operator -(Money other) {
    final result = piasters - other.piasters;
    if (result < 0) throw ArgumentError('النتيجة لا يمكن أن تكون سالبة');
    return Money(result);
  }

  bool operator >(Money other) => piasters > other.piasters;
  bool operator >=(Money other) => piasters >= other.piasters;
  bool operator <(Money other) => piasters < other.piasters;
  bool operator <=(Money other) => piasters <= other.piasters;

  @override
  int compareTo(Money other) => piasters.compareTo(other.piasters);

  @override
  bool operator ==(Object other) =>
      other is Money && other.piasters == piasters;

  @override
  int get hashCode => piasters.hashCode;

  @override
  String toString() => asDouble.toStringAsFixed(2);
}
