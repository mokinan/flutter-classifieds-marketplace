import 'package:marketplace/l10n/l10n.dart';

/// "now", "5 min", "3 h", "2 d", or a date for older items — the compact
/// style classifieds use.
String relativeTime(AppLocalizations l10n, DateTime time, {required DateTime now}) {
  final age = now.difference(time);
  if (age.inMinutes < 1) return l10n.timeNow;
  if (age.inHours < 1) return l10n.timeMinutes(age.inMinutes);
  if (age.inDays < 1) return l10n.timeHours(age.inHours);
  if (age.inDays < 30) return l10n.timeDays(age.inDays);
  return l10n.timeMonths(age.inDays ~/ 30);
}
