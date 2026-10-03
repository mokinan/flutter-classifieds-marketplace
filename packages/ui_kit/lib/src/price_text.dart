import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// Formats an integer amount of halalas as Saudi riyals, e.g. `1,250 SAR` or
/// `37.46 SAR`. Whole amounts omit the decimals, as classifieds usually do.
String formatSar(int halalas, String locale) {
  final whole = halalas % 100 == 0;
  final format = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: whole ? 0 : 2);
  final major = halalas ~/ 100;
  final text = whole ? format.format(major) : format.format(halalas / 100);
  return '$text SAR';
}

class PriceText extends StatelessWidget {
  const PriceText(this.halalas, {this.style, super.key});

  final int halalas;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    return Text(
      formatSar(halalas, locale),
      textDirection: TextDirection.ltr,
      style: (style ?? theme.textTheme.titleMedium)?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
