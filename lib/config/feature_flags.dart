import 'package:flutter/foundation.dart' show kIsWeb;

bool get paidListingsEnabled => paidListingsEnabledForPlatform(kIsWeb);

bool paidListingsEnabledForPlatform(bool isWeb) => isWeb;
