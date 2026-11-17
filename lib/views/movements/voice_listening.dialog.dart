import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/movement.model.dart';
import 'package:money/services/ai.service.dart';

const double _micRadius = 32;
const double _micIconSize = 32;
const double _pulseScale = 1.25;
const Duration _pulseDuration = Duration(milliseconds: 900);
const double _transcriptMinHeight = 56;

const _failureMessages = {
  AIFailure.permissionDenied: 'Necesito permiso de micrófono y de reconocimiento de voz.',
  AIFailure.nothingHeard: 'No escuché nada. Intentá de nuevo.',
  AIFailure.interpretationFailed: 'No pude interpretar el movimiento.',
  AIFailure.offline: 'No pude conectarme. Revisá tu conexión.',
};

enum _VoiceDialogStage {
  listening,
  interpreting,
  failed,
}

class VoiceListeningDialog extends StatefulWidget {
  final MovementPromptContext promptContext;

  const VoiceListeningDialog({ super.key, required this.promptContext });

  @override
  State<VoiceListeningDialog> createState() => _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends State<VoiceListeningDialog> with SingleTickerProviderStateMixin {
  final AIService aiService = GetIt.instance.get<AIService>();
  late final AnimationController pulseController = AnimationController(vsync: this, duration: _pulseDuration);
  _VoiceDialogStage stage = _VoiceDialogStage.listening;
  String partialTranscript = '';
  String errorMessage = '';
  bool finished = false;

  bool get canFinish {
    return stage == _VoiceDialogStage.listening;
  }

  @override
  void initState() {
    super.initState();
    pulseController.repeat(reverse: true);
    aiService.listen(
      widget.promptContext,
      onPartialTranscript: handlePartialTranscript,
      onListeningFinished: handleListeningFinished,
    ).then(handleResult, onError: handleError);
  }

  @override
  void dispose() {
    pulseController.dispose();
    if (!finished) aiService.cancel();
    super.dispose();
  }

  void handlePartialTranscript(String text) {
    if (!mounted) return;
    setState(() {
      partialTranscript = text;
    });
  }

  void handleListeningFinished() {
    if (!mounted || stage != _VoiceDialogStage.listening) return;
    setState(() {
      stage = _VoiceDialogStage.interpreting;
    });
  }

  void handleResult(Movement movement) {
    finished = true;
    if (!mounted) return;
    Navigator.of(context).pop(movement);
  }

  void handleError(Object error) {
    finished = true;
    if (!mounted) return;
    var failure = error is AIException ? error.failure : AIFailure.interpretationFailed;
    if (failure == AIFailure.cancelled) return;
    setState(() {
      stage = _VoiceDialogStage.failed;
      errorMessage = _failureMessages[failure]!;
    });
  }

  Future<void> finishListening() async {
    setState(() {
      stage = _VoiceDialogStage.interpreting;
    });
    await aiService.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTitle(context),
            const SizedBox(height: 20),
            buildStatus(context),
            const SizedBox(height: 15),
            buildTranscript(context),
            const SizedBox(height: 20),
            buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    return Text('Te escucho…', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold));
  }

  Widget buildStatus(BuildContext context) {
    switch (stage) {
      case _VoiceDialogStage.listening:
        return buildListeningStatus(context);
      case _VoiceDialogStage.interpreting:
        return buildInterpretingStatus(context);
      case _VoiceDialogStage.failed:
        return buildFailedStatus(context);
    }
  }

  Widget buildListeningStatus(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1, end: _pulseScale).animate(pulseController),
          child: CircleAvatar(
            radius: _micRadius,
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.mic, color: Colors.white, size: _micIconSize),
          ),
        ),
        const SizedBox(height: 15),
        const Text('Escuchando…', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget buildInterpretingStatus(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 15),
        Text('Interpretando…', style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget buildFailedStatus(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: _micIconSize),
        const SizedBox(height: 15),
        Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget buildTranscript(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _transcriptMinHeight),
      child: Center(
        child: Text(partialTranscript, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget buildActionButtons(BuildContext context) {
    if (stage == _VoiceDialogStage.failed) {
      return buildCancelButton(context, 'Cerrar');
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        buildCancelButton(context, 'Cancelar'),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canFinish ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
            foregroundColor: Colors.white,
            fixedSize: const Size(120, 30),
          ),
          onPressed: canFinish ? finishListening : null,
          child: const Text('Listo', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget buildCancelButton(BuildContext context, String label) {
    return TextButton(
      style: ButtonStyle(fixedSize: WidgetStateProperty.all(const Size(120, 30))),
      onPressed: () {
        Navigator.of(context).pop();
      },
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
    );
  }
}
