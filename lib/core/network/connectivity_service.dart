import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';


/// خدمة مركزية لمراقبة حالة الاتصال بالشبكة.
/// تعرض حالة الاتصال الحالي وبث تحديثاتها للواجهات والطبقات الأخرى.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  final List<bool> _recentStates = [];

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _controller.stream;

  void _init() {
    _checkCurrent().then((_) {
      _subscription = _connectivity.onConnectivityChanged.listen(
        (_) => _checkCurrent(),
        onError: (Object e) {
          debugPrint('ConnectivityService stream error: $e');
        },
      );
    });
  }

  Future<void> _checkCurrent() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = !results.contains(ConnectivityResult.none);
      _emit(online);
    } catch (e) {
      debugPrint('ConnectivityService check error: $e');
      // عند الفشل نفترض الاتصال متاحًا لتجنب حجب العمليات ظلمًا.
      _emit(true);
    }
  }

  void _emit(bool online) {
    // تنعيم التغيرات السريعة (رفع/هبوط الشبكة) لتجنب وميض الواجهة.
    _recentStates.add(online);
    if (_recentStates.length > 3) _recentStates.removeAt(0);
    final stable = _recentStates.where((s) => s == online).length >= 2 ||
        _recentStates.length < 2;
    if (!stable) return;

    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  /// التحقق الفوري من الاتصال.
  Future<bool> checkNow() async {
    await _checkCurrent();
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
