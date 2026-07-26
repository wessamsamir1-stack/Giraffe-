import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _slides = [
    (
      icon: Icons.swap_horiz_rounded,
      titleKey: 'onb.slide1.title',
      bodyKey: 'onb.slide1.body',
    ),
    (
      icon: Icons.lock_open_rounded,
      titleKey: 'onb.slide2.title',
      bodyKey: 'onb.slide2.body',
    ),
    (
      icon: Icons.auto_awesome_rounded,
      titleKey: 'onb.slide3.title',
      bodyKey: 'onb.slide3.body',
    ),
  ];

  void _next() {
    if (_index < _slides.length - 1) {
      _pages.nextPage(duration: GDuration.base, curve: GCurve.standard);
    } else {
      context.go(R.onbLanguage);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.lg,
                  vertical: GSpace.sm,
                ),
                child: TextButton(
                  onPressed: () => context.go(R.onbLanguage),
                  child: Text(
                    context.tr('common.skip'),
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: c.textTertiary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GSpace.xxxl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            color: c.brandSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 62, color: c.brand),
                        ),
                        const SizedBox(height: GSpace.huge),
                        Text(
                          context.tr(slide.titleKey),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: GSpace.lg),
                        Text(
                          context.tr(slide.bodyKey),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: c.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            GProgressDots(count: _slides.length, index: _index),
            const SizedBox(height: GSpace.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.screenH),
              child: Column(
                children: [
                  GButton(
                    label: context.tr(isLast ? 'onb.start' : 'common.next'),
                    onPressed: _next,
                    trailingIcon: isLast ? null : Icons.arrow_forward_rounded,
                  ),
                  const SizedBox(height: GSpace.md),
                  TextButton(
                    onPressed: () => context.go(R.signIn),
                    child: Text(
                      context.tr('onb.haveAccount'),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSpace.lg),
          ],
        ),
      ),
    );
  }
}
