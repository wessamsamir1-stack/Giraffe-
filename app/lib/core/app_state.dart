import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/countries.dart';

/// حالة التطبيق العامة.
///
/// في النسخة المبدئية كل ده في الذاكرة. لما يتربط سوبابيز، الـ providers
/// دي هي نقاط الربط — الشاشات نفسها مش هتتغير.

// ------------------------------------------------------------------ اللغة
final localeProvider = StateProvider<Locale>((ref) => const Locale('ar'));

// ------------------------------------------------------------------ المظهر
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// ------------------------------------------------------------------ الدولة
final countryProvider = StateProvider<Country>((ref) => Countries.egypt);

final cityProvider = StateProvider<City>((ref) => Countries.egypt.cities.first);

// ------------------------------------------------------------------ الجلسة
enum AuthStage {
  loggedOut,
  needsProfile,
  needsLocation,
  needsWishlist,
  ready,
}

/// مرحلة المستخدم في رحلة الإعداد.
///
/// الـ router بيقرأ منها عشان يمنع تخطي الخطوات الإجبارية —
/// وأهمها **قائمة الرغبات**، لأن من غيرها محرك المطابقة ما بيشتغلش.
final authStageProvider = StateProvider<AuthStage>((ref) => AuthStage.ready);

// ------------------------------------------------------------------ مسودة الإعداد
/// بيانات الإعداد الأولي قبل ما تتحفظ.
///
/// شاشة الملف بتملاها، وشاشة الموقع بتكمّلها وتحفظ الاتنين مرة واحدة —
/// عشان مانعملش صف ملف ناقص لو المستخدم قفل التطبيق في النص.
class SetupDraft {
  const SetupDraft({
    this.displayName = '',
    this.username = '',
    this.bio = '',
    this.avatarPath,
  });

  final String displayName;
  final String username;
  final String bio;
  final String? avatarPath;

  SetupDraft copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? avatarPath,
  }) =>
      SetupDraft(
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        bio: bio ?? this.bio,
        avatarPath: avatarPath ?? this.avatarPath,
      );
}

final setupDraftProvider = StateProvider<SetupDraft>((ref) => const SetupDraft());

// ------------------------------------------------------------------ حدود يومية
/// عدد السحبات المتبقية النهارده للمستخدم العادي.
final swipesLeftProvider = StateProvider<int>((ref) => 50);

/// عدد صفقات الأحلام المتبقية النهارده.
final dreamsLeftProvider = StateProvider<int>((ref) => 3);

/// أقصى عدد غرف مقايضة نشطة.
const int kMaxActiveRooms = 10;

/// أقصى عدد عناصر في قائمة الرغبات للمستخدم العادي.
const int kMaxWishlistItems = 10;

/// أقل عدد عناصر مطلوب في الإعداد الأولي.
const int kMinWishlistItems = 3;
