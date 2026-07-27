import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../splash/splash_screen.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const GiraffeMark(size: 84),
              const SizedBox(height: GSpace.xxl),
              Text(
                context.tr('auth.welcome'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                context.tr('auth.welcomeBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(flex: 3),

              GSocialButton(
                label: context.tr('auth.continueGoogle'),
                icon: Icons.g_mobiledata_rounded,
                onPressed: () => context.go(R.onbProfile),
              ),
              const SizedBox(height: GSpace.md),
              GSocialButton(
                label: context.tr('auth.continueApple'),
                icon: Icons.apple_rounded,
                onPressed: () => context.go(R.onbProfile),
              ),

              const SizedBox(height: GSpace.xl),
              Row(
                children: [
                  Expanded(child: Divider(color: c.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
                    child: Text(
                      context.tr('auth.or'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(child: Divider(color: c.border)),
                ],
              ),
              const SizedBox(height: GSpace.xl),

              GButton(
                label: context.tr('auth.continueEmail'),
                icon: Icons.mail_outline_rounded,
                style: GButtonStyle.ghost,
                onPressed: () => context.push(R.signUp),
              ),

              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.tr('auth.hasAccount'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: GSpace.xs),
                    GestureDetector(
                      onTap: () => context.push(R.signIn),
                      child: Text(
                        context.tr('auth.signIn'),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.brand),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: GSpace.lg),
                child: Text(
                  context.tr('auth.terms'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.textTertiary, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
