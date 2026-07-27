import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/app_state.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();

  bool _filled = false;
  bool _saving = false;

  Future<void> _save() async {
    final me = ref.read(myProfileProvider).valueOrNull;
    if (me == null) return;

    setState(() => _saving = true);

    final error = await ref.read(profileRepositoryProvider).upsert(
          displayName: _name.text,
          username: _username.text,
          bio: _bio.text,
          countryCode: me.countryCode,
          cityId: me.cityId,
          areaId: me.areaId,
          locale: ref.read(localeProvider).languageCode,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error))),
      );
      return;
    }

    ref.invalidate(myProfileProvider);
    if (mounted) context.pop();
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
    final me = ref.watch(myProfileProvider).valueOrNull;

    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('profile.edit'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // تعبئة الحقول مرة واحدة بس — عشان مانمسحش اللي المستخدم بيكتبه
    if (!_filled) {
      _filled = true;
      _name.text = me.displayName;
      _username.text = me.username;
      _bio.text = me.bio;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.edit'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Center(
            child: Stack(
              children: [
                GAvatar(
                  name: me.displayName,
                  seed: me.avatarSeed,
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
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
