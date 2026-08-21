import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/backup_service.dart';

part 'backup_providers.g.dart';

@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) => BackupService();
