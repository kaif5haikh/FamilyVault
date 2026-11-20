import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/vault_strings.dart';

/// Default categories have app-owned names. Names the family typed are records.
String accountDisplayName(BuildContext context, LedgerAccount account) =>
    account.systemAccount ? context.tr(account.name) : account.name;
