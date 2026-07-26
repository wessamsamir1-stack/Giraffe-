import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';
import '../../widgets/item_card.dart';
import 'trade_room_screen.dart';

/// إنشاء عرض مقايضة.
///
/// الفرق النقدي مسموح ومهم — هو اللي بيقفل معظم الصفقات الواقعية.
/// بس الفلوس بتتدفع **يد بيد عند اللقاء** — مفيش أي معالجة دفع.
class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key, required this.matchId});

  final String matchId;

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final _cash = TextEditingController();
  late Item _mine = Mock.match(widget.matchId).myItem;
  late Item _theirs = Mock.match(widget.matchId).theirItem;
  bool _iPay = true;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  double get _delta {
    final value = double.tryParse(_cash.text) ?? 0;
    return _iPay ? value : -value;
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('room.makeOffer'))),
      body: ListView(
        padding: const EdgeInsets.all(GSpace.screenH),
        children: [
          Text(
            context.tr('offer.pickYours'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          for (final item in Mock.myItems)
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.sm),
              child: _SelectableItem(
                item: item,
                selected: _mine.id == item.id,
                onTap: () => setState(() => _mine = item),
              ),
            ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('offer.pickTheirs'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          _SelectableItem(item: _theirs, selected: true, onTap: () {}),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('offer.cashDiff'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          Row(
            children: [
              GChip(
                label: context.tr('deck.youPay'),
                selected: _iPay,
                onTap: () => setState(() => _iPay = true),
              ),
              const SizedBox(width: GSpace.sm),
              GChip(
                label: context.tr('deck.youGet'),
                selected: !_iPay,
                onTap: () => setState(() => _iPay = false),
              ),
            ],
          ),
          const SizedBox(height: GSpace.md),
          GTextField(
            label: _mine.country.currency.code,
            controller: _cash,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.payments_outlined,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: GSpace.xxl),
          Text(
            context.tr('offer.preview'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          OfferCard(
            showActions: false,
            offer: TradeOffer(
              id: 'preview',
              giveItem: _mine,
              getItem: _theirs,
              cashDelta: _delta,
              status: OfferStatus.pending,
              fromMe: true,
            ),
          ),

          const SizedBox(height: GSpace.lg),
          GNotice(
            tone: GNoticeTone.warning,
            icon: Icons.savings_outlined,
            text: ar
                ? 'الفرق النقدي بيتدفع يد بيد عند اللقاء. Giraffe مش طرف في الدفع ومش بيحتفظ بأي فلوس.'
                : 'Cash changes hands in person. Giraffe is not a party to the payment and holds no funds.',
          ),

          const SizedBox(height: GSpace.xl),
          GButton(
            label: context.tr('offer.send'),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

class _SelectableItem extends StatelessWidget {
  const _SelectableItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final Item item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        ItemRow(item: item, onTap: onTap, showStatus: false),
        if (selected)
          PositionedDirectional(
            top: GSpace.md,
            end: GSpace.md,
            child: Icon(Icons.check_circle_rounded, size: 20, color: c.brand),
          ),
      ],
    );
  }
}
