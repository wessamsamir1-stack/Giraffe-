import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController(text: Mock.me.displayName);
  final _username = TextEditingController(text: Mock.me.username);
  final _bio = TextEditingController(text: Mock.me.bio);

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
      appBar: AppBar(title: Text(context.tr('profile.edit'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Center(
            child: Stack(
              children: [
                GAvatar(
                  name: Mock.me.displayName,
                  seed: Mock.me.avatarSeed,
                  size: GSize.avatarXl,
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.background, width: 2.2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: c.onBrand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GSpace.xxl),

          GTextField(
            label: context.tr('setup.displayName'),
            controller: _name,
            prefixIcon: Icons.badge_outlined,
            maxLength: 40,
          ),
          const SizedBox(height: GSpace.lg),
          GTextField(
            label: context.tr('setup.username'),
            controller: _username,
            prefixIcon: Icons.alternate_email_rounded,
            maxLength: 20,
          ),
          const SizedBox(height: GSpace.lg),
          GTextField(
            label: context.tr('setup.bio'),
            controller: _bio,
            maxLines: 4,
            maxLength: 160,
          ),

          const SizedBox(height: GSpace.xl),
          GNotice(
            icon: Icons.privacy_tip_outlined,
            text: context.tr('setup.location.body'),
          ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('common.save'),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
