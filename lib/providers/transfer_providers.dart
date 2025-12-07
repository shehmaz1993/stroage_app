import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_model.dart';
import '../services/api_services.dart';
import '../services/file_selection_service.dart';
import '../services/local_notification_service.dart';
import '../services/transfer_persistance_service.dart';
import '../services/transfer_service.dart';

import 'package:dio/dio.dart';

import '../state/transfer_notifier.dart';

// --- Service Providers (Assuming Dio is provided elsewhere) ---
final dioProvider = Provider((ref) => Dio());

// Initialize all necessary services
final apiProvider = Provider((ref) => ApiProvider(ref.watch(dioProvider)));
final notificationServiceProvider = Provider((ref) => NotificationService());
final persistenceServiceProvider = Provider((ref) => TransferPersistenceService());
final fileSelectionServiceProvider = Provider((ref) => FileSelectionService());


// The TransferService depends on all other services
final transferServiceProvider = Provider((ref) => TransferService(
  ref.watch(apiProvider),
  ref.watch(notificationServiceProvider),
  ref.watch(persistenceServiceProvider),
));

// --- State Provider ---
final transferNotifierProvider = StateNotifierProvider<TransferNotifier, List<FileTransfer>>((ref) {
  return TransferNotifier(ref.watch(transferServiceProvider));
});