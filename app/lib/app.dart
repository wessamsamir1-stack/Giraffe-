import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_state.dart';
import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/providers.dart';
import 'data/repositories/push_repository.dart';

final _routerProvider = Provider<GoRouter>((ref) => buildRouter());

class GiraffeApp extends ConsumerStatefulWidget {
  const GiraffeApp({super.key});

  @override
  ConsumerState<GiraffeApp> createState() => _GiraffeAppState();
}

class _GiraffeAppState extends ConsumerState<GiraffeApp> {
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<Map<String, dynamic>>? _openedSub;

  @override
  void initState() {
    super.initState();
    // بعد أول إطار عشان الـ router يكون جاهز للتوجيه
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPush());
  }

  Future<void> _initPush() async {
    final push = ref.read(pushRepositoryProvider);

    // التسجيل بيتعاد كل مرة التطبيق بيفتح — الرمز بيتجدّد من فايربيز
    // من نفسه، والتسجيل عملية رخيصة (upsert).
    unawaited(push.registerDevice());

    _tokenSub = push.watchTokenRefresh();

    _openedSub = push.onOpened.listen((payload) {
      final route = routeForPayload(payload);
      if (route != null && mounted) {
        ref.read(_routerProvider).go(route);
      }
    });
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Giraffe',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      supportedLocales: S.supported,
      localizationsDelegates: const [
        GLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      themeMode: themeMode,
      builder: (context, child) {
        // تثبيت حجم الخط في حدود معقولة عشان التصميم ما يتكسرش
        // مع إعدادات الإتاحة القصوى، مع احترام تكبير المستخدم.
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.35,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
