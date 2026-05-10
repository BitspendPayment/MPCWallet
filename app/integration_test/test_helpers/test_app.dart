import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/main.dart' show MerlinWalletApp;
import 'package:app/services/backup_store.dart';
import 'package:app/services/mpc_service.dart';

Widget buildTestApp({required BackupStore backupStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) {
        final svc = MpcService(backupStore: backupStore);
        svc.initFuture = svc.init();
        return svc;
      }),
    ],
    child: const MerlinWalletApp(),
  );
}
