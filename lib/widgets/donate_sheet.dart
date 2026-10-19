import 'package:flutter/material.dart';
import 'package:luvedube/services/donation_service.dart';
import 'package:luvedube/theme/app_theme.dart';
import 'package:luvedube/widgets/tech_widgets.dart';

/// Shows the donate sheet.
/// Returns true  → user chose "Exit app"
/// Returns false → user chose "Keep writing" or dismissed the sheet.
Future<bool> showDonateSheet(BuildContext context) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DonateSheet(),
  );
  return r ?? false;
}

class _DonateSheet extends StatefulWidget {
  const _DonateSheet();

  @override
  State<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<_DonateSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  final TextEditingController _custom = TextEditingController();
  int? _selected = 29;
  String? _status;
  bool _statusOk = true;

  @override
  void dispose() {
    _pulse.dispose();
    _custom.dispose();
    super.dispose();
  }

  int? get _amount {
    final typed = int.tryParse(_custom.text.trim());
    if (typed != null && typed > 0) return typed;
    return _selected;
  }

  Future<void> _donate() async {
    final ok = await DonationService.openUpi(amount: _amount);
    if (!mounted) return;
    if (!ok) await DonationService.copyUpiId();
    if (!mounted) return;
    setState(() {
      _statusOk = ok;
      _status = ok
          ? 'Thank you for your kindness ❤️  Payment happens in your UPI app — you can cancel there anytime. No pressure!'
          : 'No UPI app found. UPI ID copied — paste it in any UPI app.';
    });
  }

  Future<void> _copy() async {
    await DonationService.copyUpiId();
    if (!mounted) return;
    setState(() {
      _statusOk = true;
      _status = 'UPI ID copied: ${DonationConfig.upiId}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: GlassCard(
          blur: true,
          radius: 28,
          accent: Tech.magenta,
          baseColor: Tech.surface.withValues(alpha: .9),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                ScaleTransition(
                  scale: Tween<double>(begin: .9, end: 1.08).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Tech.magenta, Tech.violet],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Tech.magenta.withValues(alpha: .5),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                const GradientText(
                  DonationConfig.headline,
                  gradient: Tech.brand,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  DonationConfig.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Tech.text, fontSize: 14.5, height: 1.45),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (amt, label) in DonationConfig.presets)
                      _AmountChip(
                        amount: amt,
                        label: label,
                        selected: _selected == amt && _custom.text.isEmpty,
                        onTap: () => setState(() {
                          _selected = amt;
                          _custom.clear();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Or enter your own amount (₹)',
                    prefixText: '₹ ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: NeonButton(
                    icon: Icons.volunteer_activism_rounded,
                    label: _amount == null
                        ? 'Donate with UPI'
                        : 'Donate ₹$_amount with UPI',
                    onTap: _donate,
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusOk ? Tech.mint : Tech.amber,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy UPI ID'),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Tech.text,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep writing'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Tech.muted,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: .12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Exit app'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '🔒 Payment happens inside your own UPI app.\nLuveDuve never sees your payment details.',
                  textAlign: TextAlign.center,
                  style: Tech.mono(size: 10, spacing: .4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.amount,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(14);
    return InkWell(
      borderRadius: r,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: selected ? Tech.brand : null,
          color: selected ? null : Colors.white.withValues(alpha: .04),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white24,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Tech.violet.withValues(alpha: .45),
                    blurRadius: 14,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text('₹$amount',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: Tech.mono(
                    size: 10,
                    color: selected ? Colors.white : Tech.muted,
                    spacing: .6)),
          ],
        ),
      ),
    );
  }
}
