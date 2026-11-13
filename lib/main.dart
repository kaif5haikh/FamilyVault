import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Cloud access and vault opening stay disabled until their review gates pass.
  runApp(const ProviderScope(child: FamilyVaultApp()));
}
