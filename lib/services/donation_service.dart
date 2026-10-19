import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// ─────────── EDIT THESE ───────────
class DonationConfig {
  static const String upiId = ''; // <-- put YOUR UPI ID here
  static const String payeeName = 'LuveDuve';
  static const String note = 'Support LuveDuve';

  static const String headline = 'Before you go…';
  static const String message =
      'LuveDuve is built by one independent developer and is free for every '
      'songwriter. If it helped you write even one line you love, a small '
      'donation keeps it alive — updates, new features, no paywalls.\n\n'
      'Even ₹10 genuinely makes my day. 💜';

  /// (amount in ₹, tiny label)
  static const List<(int, String)> presets = [
    (10, 'Chai'),
    (29, 'Coffee'),
    (49, 'Snack'),
    (99, 'Meal'),
  ];
}

class DonationService {
  static Uri buildUpiUri({int? amount}) {
    String enc(String s) => Uri.encodeComponent(s); // %20 not '+', UPI apps need it
    final b = StringBuffer('upi://pay')
      ..write('?pa=${DonationConfig.upiId}')
      ..write('&pn=${enc(DonationConfig.payeeName)}')
      ..write('&tn=${enc(DonationConfig.note)}')
      ..write('&cu=INR');
    if (amount != null && amount > 0) b.write('&am=$amount.00');
    return Uri.parse(b.toString());
  }

  /// Opens the user's UPI app chooser. The user can pay or simply cancel
  /// inside their own UPI app. Returns false if no UPI app could be opened.
  static Future<bool> openUpi({int? amount}) async {
    try {
      return await launchUrl(
        buildUpiUri(amount: amount),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> copyUpiId() =>
      Clipboard.setData(const ClipboardData(text: DonationConfig.upiId));
}
