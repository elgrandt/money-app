import 'package:money/models/account.model.dart';
import 'package:money/models/category.model.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/repositories/movements.repository.dart';

enum AIFailure {
  permissionDenied,
  nothingHeard,
  interpretationFailed,
  cancelled,
}

class AIException implements Exception {
  final AIFailure failure;

  const AIException(this.failure);

  @override
  String toString() {
    return 'AIException(${ failure.name })';
  }
}

class MovementPromptContext {
  final DateTime now;
  final List<Account> accounts;
  final Map<MovementType, List<Category>> categoriesByType;
  final Account? screenAccount;
  final List<DescriptionCategoryUsage> descriptionUsages;

  const MovementPromptContext({ required this.now, required this.accounts, required this.categoriesByType, this.screenAccount, this.descriptionUsages = const [] });
}

abstract class AIService {
  Future<bool> isAvailable();

  Future<Movement> listen(
    MovementPromptContext context, {
    required void Function(String text) onPartialTranscript,
    required void Function() onListeningFinished,
  });

  Future<void> stop();
  Future<void> cancel();
}
