import 'package:flutter/widgets.dart';
import 'package:marketplace/l10n/gen/app_localizations.dart';
import 'package:marketplace_api/marketplace_api.dart';

export 'package:marketplace/l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}

extension L10nDomain on AppLocalizations {
  String categoryName(String slug) => switch (slug) {
    'vehicle' => category_vehicle,
    'motorcycle' => category_motorcycle,
    'smartphones' => category_smartphones,
    'laptops' => category_laptops,
    'tablets' => category_tablets,
    'mobile-accessories' => category_mobile_accessories,
    'furniture' => category_furniture,
    'home-decoration' => category_home_decoration,
    'kitchen-accessories' => category_kitchen_accessories,
    'mens-watches' => category_mens_watches,
    'sports-accessories' => category_sports_accessories,
    _ => slug,
  };

  String cityName(String city) => switch (city) {
    'Riyadh' => city_Riyadh,
    'Jeddah' => city_Jeddah,
    'Dammam' => city_Dammam,
    'Makkah' => city_Makkah,
    'Madinah' => city_Madinah,
    'Khobar' => city_Khobar,
    'Abha' => city_Abha,
    'Tabuk' => city_Tabuk,
    _ => city,
  };

  /// Maps API failures to user-facing text; details stay in logs.
  String errorTitle(ApiException? error) => switch (error) {
    NetworkUnavailable() => errorNetwork,
    _ => errorServer,
  };
}
