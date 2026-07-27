import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_common.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('safety.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Container(
            padding: const EdgeInsets.all(GSpace.xl),
            decoration: BoxDecoration(
              color: c.success.withOpacity(0.10),
              borderRadius: GRadius.brXl,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 42,
                  color: c.success,
                ),
                const SizedBox(height: GSpace.md),
                Text(
                  ar
                      ? 'الصفقة الآمنة أهم من الصفقة السريعة'
                      : 'A safe trade beats a fast trade',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),

          const SizedBox(height: GSpace.xl),
          Text(
            ar ? 'قواعد اللقاء' : 'Meeting rules',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GSpace.md),
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.sm),
              child: GSurface(
                padding: const EdgeInsets.all(GSpace.md),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c.success.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: TextStyle(
                            color: c.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: Text(
                        context.tr('safety.rule$i'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('safety.banned'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GSpace.md),
          GNotice(
            tone: GNoticeTone.danger,
            icon: Icons.gavel_rounded,
            text: context.tr('safety.bannedBody'),
          ),

          const SizedBox(height: GSpace.xl),
          GNotice(
            tone: GNoticeTone.warning,
            icon: Icons.savings_outlined,
            text: ar
                ? 'Giraffe مش طرف في أي عملية دفع ومش بيحتفظ بأي فلوس. أي حد يطلب منك تحويل قبل اللقاء = محاولة نصب، بلّغ عنه فوراً.'
                : 'Giraffe is never a party to payment and holds no funds. Anyone asking for a transfer before meeting is attempting a scam — report them.',
          ),
        ],
      ),
    );
  }
}
