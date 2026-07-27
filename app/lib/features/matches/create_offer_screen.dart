import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/models.dart';
import '../../data/repositories/providers.dart';
import '../../widgets/g_button.dart';
import '../../widgets/g_common.dart';
import '../../widgets/g_text_field.dart';
import '../../widgets/item_card.dart';
import 'trade_room_screen.dart';

/// إنشاء عرض مقايضة.
///
/// الفرق النقدي مسموح ومهم — هو اللي بيقفل معظم الصفقات الواقعية.
/// بس الفلوس بتتدفع **يد بيد عند اللقاء** — مفيش أي معالجة دفع.
class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final _cash = TextEditingController();
  Item? _mine;
  bool _iPay = true;
  bool _sending = false;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  double get _delta {
    final value = double.tryParse(_cash.text) ?? 0;
    return _iPay ? value : -value;
  }

  Future<void> _send(Item mine, Item theirs) async {
    setState(() => _sending = true);

    final error = await ref.read(matchesRepositoryProvider).createOffer(
          matchId: widget.matchId,
          giveItemId: mine.id,
          getItemId: theirs.id,
          cashDelta: _delta,
          currencyCode: mine.currencyCode,
        );

    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error))),
      );
      return;
    }

    ref.invalidate(matchProvider(widget.matchId));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.s.isArabic;

    final match = ref.watch(matchProvider(widget.matchId)).valueOrNull;
    final myItems = ref.watch(myItemsProvider).valueOrNull ?? const <Item>[];

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('room.makeOffer'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theirs = match.theirItem;
    final mine = _mine ?? match.myItem;

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
          for (final item in (myItems.isEmpty ? [mine] : myItems))
            Padding(
              padding: const EdgeInsets.only(bottom: GSpace.sm),
              child: _SelectableItem(
                item: item,
                selected: mine.id == item.id,
                onTap: () => setState(() => _mine = item),
              ),
            ),

          const SizedBox(height: GSpace.xl),
          Text(
            context.tr('offer.pickTheirs'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GSpace.sm),
          _SelectableItem(item: theirs, selected: true, onTap: () {}),

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
            label: mine.country.currency.code,
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
              giveItem: mine,
              getItem: theirs,
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
            loading: _sending,
            onPressed: () => _send(mine, theirs),
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
