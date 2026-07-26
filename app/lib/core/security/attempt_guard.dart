import 'dart:async';

import 'package:flutter/foundation.dart';

/// حارس المحاولات — تباطؤ تصاعدي بعد المحاولات الفاشلة.
///
/// بيمنع تجربة كلمات السر والأكواد بالتكرار من نفس الجهاز.
///
/// مهم: ده **طبقة تجربة استخدام مش طبقة أمان**.
/// المهاجم الحقيقي بيكلم الـ API مباشرة ومش هيعدي من هنا خالص.
/// التحديد الحقيقي لازم يكون على الخادم بالـ IP والحساب والجهاز.
class AttemptGuard extends ChangeNotifier {
  AttemptGuard({this.maxAttempts = 5});

  final int maxAttempts;

  int _failed = 0;
  int _lockSeconds = 0;
  Timer? _timer;

  int get failedAttempts => _failed;
  int get attemptsLeft => (maxAttempts - _failed).clamp(0, maxAttempts);
  int get lockSecondsLeft => _lockSeconds;
  bool get isLocked => _lockSeconds > 0;

  /// تباطؤ تصاعدي: 15 ثانية ← 30 ← 60 ← 120 ← 300 كحد أقصى.
  static const List<int> _backoff = [15, 30, 60, 120, 300];

  void recordFailure() {
    _failed++;
    if (_failed >= maxAttempts) {
      final index = (_failed - maxAttempts).clamp(0, _backoff.length - 1);
      _startLock(_backoff[index]);
      _failed = maxAttempts;
    }
    notifyListeners();
  }

  void recordSuccess() {
    _failed = 0;
    _stopLock();
    notifyListeners();
  }

  void _startLock(int seconds) {
    _lockSeconds = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _lockSeconds--;
      if (_lockSeconds <= 0) {
        _lockSeconds = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _stopLock() {
    _timer?.cancel();
    _timer = null;
    _lockSeconds = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// عدّاد إعادة إرسال كود التحقق.
class ResendCooldown extends ChangeNotifier {
  ResendCooldown({this.initialSeconds = 60});

  final int initialSeconds;

  int _seconds = 0;
  int _round = 0;
  Timer? _timer;

  int get secondsLeft => _seconds;
  bool get canResend => _seconds == 0;

  /// كل إعادة إرسال بتضاعف مدة الانتظار: 60 ← 120 ← 240 ثانية.
  void start() {
    _seconds = initialSeconds * (1 << _round.clamp(0, 2));
    _round++;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _seconds--;
      if (_seconds <= 0) {
        _seconds = 0;
        t.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
