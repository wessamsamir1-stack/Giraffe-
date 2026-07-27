import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import 'qr_scan_sheet.dart';
import 'trade_code.dart';

/// إتمام الصفقة بتأكيد الطرفين.
///
/// القاعدة الحاكمة:
///
///   **الكود اللي بمسحه بتاع التاني، واللي بيتأكد هو صفي أنا.**
///
/// يعني مستحيل حد يأكد لوحده — لازم يكون شايف شاشة التاني. وده اللي
/// بيمنع حسابين متعاونين إنهم يسجلوا صفقات وهمية لرفع مستوى الثقة.
///
/// الكود بيتولّد على الخادم. الشكل القديم كان مشتق من رقم الغرفة —
/// والطرفين عندهم رقم الغرفة، فكان كل واحد يقدر يحسب كود التاني وهو
/// قاعد في بيته.
class CompleteTradeScreen extends ConsumerStatefulWidget {
  const CompleteTradeScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<CompleteTradeScreen> createState() =>
      _CompleteTradeScreenState();
}

class _CompleteTradeScreenState extends ConsumerState<CompleteTradeScreen> {
  final _entered = TextEditingController();

  String? _myCode;
  bool _loadingCode = true;
  bool _saving = false;
  bool _confirmed = false;
  bool _otherDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entered.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(matchesRepositoryProvider);
    final code = await repo.issueTradeCode(widget.matchId);
    final other = await repo.otherSideConfirmed(widget.matchId);

    if (!mounted) return;
    setState(() {
      _myCode = code;
      _otherDone = other;
      _loadingCode = false;
    });
  }

  Future<void> _confirm() async {
    final code = _entered.text.trim();
    if (code.length < 6) {
      _toast(context.tr('complete.err.code'));
      return;
    }

    setState(() => _saving = true);

    final repo = ref.read(matchesRepositoryProvider);
    final error = await repo.confirmTrade(widget.matchId, code);

    if (!mounted) return;

    if (error != null) {
      setState(() => _saving = false);
      _toast(context.tr(error));
      return;
    }

    final other = await repo.otherSideConfirmed(widget.matchId);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _confirmed = true;
      _otherDone = other;
    });

    ref.invalidate(matchProvider(widget.matchId));
    ref.invalidate(matchesProvider(false));
  }

  /// فتح الماسح.
  ///
  /// بيرجّع الكود لو المسح نجح، والتأكيد بيتم بنفس المسار المكتوب —
  /// يعني الماسح بيملا الخانة بس، مش بيعمل مسار تاني موازي.
  ///
  /// الميزة إن التحقق والأخطاء وسقف المحاولات كلهم في مكان واحد.
  Future<void> _scan() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: GRadius.sheet),
      builder: (_) => QrScanSheet(matchId: widget.matchId),
    );

    if (code == null || !mounted) return;

    _entered.text = code;
    await _confirm();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final match = ref.watch(matchProvider(widget.matchId)).valueOrNull;

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('complete.title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('complete.title'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Text(
            context.tr('complete.body'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: GSpace.xxl),

          // -------------------------------------------------------------------
          // كودي أنا — التاني بيمسحه أو بيكتبه
          // -------------------------------------------------------------------
          Center(
            child: Column(
              children: [
                Text(
                  context.tr('complete.myCode'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: GSpace.md),
                Container(
                  padding: const EdgeInsets.all(GSpace.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: GRadius.brXl,
                    border: Border.all(color: c.border, width: 1.4),
                  ),
                  child: _loadingCode
                      ? const SizedBox(
                          width: 168,
                          height: 168,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : QrImageView(
                          // كود QR حقيقي — الرسم القديم كان تزييني،
                          // يعني الماسح ماكانش هيقراه أصلاً.
                          data: encodeTradeCode(
                            matchId: widget.matchId,
                            code: _myCode ?? '',
                          ),
                          version: QrVersions.auto,
                          size: 168,
                          // تصحيح خطأ متوسط: الشاشة بتتمسح من زاوية
                          // وفيها انعكاس، فالكود محتاج يتحمل تشويش.
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF121212),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF121212),
                          ),
                        ),
                ),
                const SizedBox(height: GSpace.md),

                // الكاميرا بتفشل في الضلمة وفي الزحمة — الكود المكتوب
                // مش خطة بديلة، ده المسار التاني الأساسي.
                if (_myCode != null)
                  SelectableText(
                    _myCode!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: GSpace.xxl),
          Divider(color: c.border, height: 1),
          const SizedBox(height: GSpace.xl),

          // -------------------------------------------------------------------
          // كود التاني — ده اللي بيأكد صفي أنا
          // -------------------------------------------------------------------
          if (!_confirmed) ...[
            Text(
              context.tr('complete.theirCode'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: GSpace.md),
            TextField(
              controller: _entered,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              style: const TextStyle(letterSpacing: 6, fontSize: 22),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
                _UpperCaseFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: '••••••••',
                counterText: '',
                border: OutlineInputBorder(borderRadius: GRadius.brLg),
              ),
            ),
            const SizedBox(height: GSpace.md),
            GButton(
              label: context.tr('scan.open'),
              icon: Icons.qr_code_scanner_rounded,
              style: GButtonStyle.secondary,
              onPressed: _saving ? null : _scan,
            ),
            const SizedBox(height: GSpace.md),
            GButton(
              label: context.tr('complete.confirm'),
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _confirm,
            ),
          ],

          const SizedBox(height: GSpace.xl),

          if (_confirmed && !_otherDone)
            GNotice(
              tone: GNoticeTone.success,
              icon: Icons.hourglass_top_rounded,
              text: context.trf('complete.waiting', {
                'name': match.other.displayName,
              }),
            ),

          if (_confirmed && _otherDone)
            GNotice(
              tone: GNoticeTone.success,
              icon: Icons.check_circle_rounded,
              text: context.tr('complete.done'),
            ),

          const SizedBox(height: GSpace.xxl),
          GButton(
            label: context.tr('rate.title'),
            style: GButtonStyle.ghost,
            onPressed: _confirmed
                ? () => context.pushReplacement(R.rate(widget.matchId))
                : null,
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

