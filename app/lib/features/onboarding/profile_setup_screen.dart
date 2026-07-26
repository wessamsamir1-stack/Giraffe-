import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/security/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();

  String? _nameError;
  String? _usernameError;

  void _submit() {
    final nameError = Validators.displayName(_name.text);
    final usernameError = Validators.username(_username.text);
    setState(() {
      _nameError = nameError;
      _usernameError = usernameError;
    });
    if (nameError == null && usernameError == null) {
      context.go(R.onbLocation);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const _SetupProgress(step: 1),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.screenH,
            GSpace.lg,
            GSpace.screenH,
            GSpace.xxxl,
          ),
          children: [
            Text(
              context.tr('setup.profile.title'),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              context.tr('setup.profile.body'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: GSpace.xxl),

            Center(
              child: GestureDetector(
                onTap: () {},
                child: Stack(
                  children: [
                    Container(
                      width: GSize.avatarXl,
                      height: GSize.avatarXl,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border, width: 1.4),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 44,
                        color: c.textTertiary,
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.background, width: 2.4),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: c.onBrand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GSpace.sm),
            Center(
              child: Text(
                context.tr('setup.addPhoto'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.brand),
              ),
            ),

            const SizedBox(height: GSpace.xxl),
            GTextField(
              label: context.tr('setup.displayName'),
              controller: _name,
              errorKey: _nameError,
              prefixIcon: Icons.badge_outlined,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            const SizedBox(height: GSpace.xl),
            GTextField(
              label: context.tr('setup.username'),
              controller: _username,
              errorKey: _usernameError,
              helper: context.tr('setup.usernameHint'),
              prefixIcon: Icons.alternate_email_rounded,
              maxLength: 20,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _usernameError = null),
            ),
            const SizedBox(height: GSpace.xl),
            GTextField(
              label: '${context.tr('setup.bio')} · ${context.tr('common.optional')}',
              controller: _bio,
              maxLines: 3,
              maxLength: 160,
            ),

            const SizedBox(height: GSpace.xxxl),
            GButton(
              label: context.tr('common.continue'),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط تقدم الإعداد الأولي — 3 خطوات إجبارية.
class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return GProgressDots(count: 3, index: step - 1);
  }
}
