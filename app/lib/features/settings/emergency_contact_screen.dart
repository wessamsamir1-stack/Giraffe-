import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/l10n/strings.dart';
import '../../core/security/validators.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

/// جهة اتصال الطوارئ.
///
/// بتتطلب أول مرة المستخدم يحدد لقاء. الرقم ده مش بيظهر لأي مستخدم
/// تاني أبداً — بيستخدم بس لما يضغط زر الطوارئ أثناء اللقاء.
class EmergencyContactScreen extends ConsumerStatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  ConsumerState<EmergencyContactScreen> createState() =>
      _EmergencyContactScreenState();
}

class _EmergencyContactScreenState
    extends ConsumerState<EmergencyContactScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final country = ref.watch(countryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('emerg.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          GNotice(
            tone: GNoticeTone.danger,
            icon: Icons.emergency_outlined,
            text: context.tr('emerg.body'),
          ),
          const SizedBox(height: GSpace.xxl),

          GTextField(
            label: context.tr('emerg.name'),
            controller: _name,
            prefixIcon: Icons.person_outline_rounded,
            maxLength: 40,
          ),
          const SizedBox(height: GSpace.lg),
          GPhoneField(
            controller: _phone,
            country: country,
            errorKey: _phoneError,
            onCountryChanged: (v) =>
                ref.read(countryProvider.notifier).state = v,
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('common.save'),
            onPressed: () {
              final error = Validators.phone(_phone.text, country);
              setState(() => _phoneError = error);
              if (error == null) context.pop();
            },
          ),
        ],
      ),
    );
  }
}
