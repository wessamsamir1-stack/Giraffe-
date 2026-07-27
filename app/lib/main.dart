import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // لو الاتصال فشل أو مفيش إعدادات، التطبيق بيكمل على البيانات التجريبية
  // بدل ما يقف على شاشة بيضا.
  await SupabaseInit.ensureInitialized();

  runApp(const ProviderScope(child: GiraffeApp()));
}
