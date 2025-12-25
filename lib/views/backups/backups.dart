import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:money/models/account.model.dart';
import 'package:money/repositories/base.repository.dart';
import 'package:money/services/database.service.dart';
import 'package:money/views/generics/navbar.dart';
import 'package:money/services/utils.service.dart';
import 'package:path_provider/path_provider.dart';

class Backups extends StatelessWidget {
  var utilsService = GetIt.instance.get<UtilsService>();

  Backups({super.key});

  saveBackup(BuildContext context) async {
    var dir = await getApplicationDocumentsDirectory();
    File file = File('${ dir.path }/db.sqlite');
    String fileName = DateTime.now().toIso8601String();
    fileName = fileName.replaceAll(':', '-');
    fileName = fileName.replaceAll('T', '-');
    fileName = fileName.substring(0, fileName.indexOf('.'));
    fileName = 'backup-$fileName.moneybak';
    await FilePicker.platform.saveFile(
      dialogTitle: 'Por favor seleccione donde guardar el backup:',
      fileName: fileName,
      bytes: await file.readAsBytes(),
    );
  }

  restoreBackup(BuildContext context) async {
    var file = await FilePicker.platform.pickFiles();
    if (file == null) return;
    var dir = await getApplicationDocumentsDirectory();
    File backup = File(file.files.single.path!);
    File db = File('${ dir.path }/db.sqlite', );
    await db.writeAsBytes(await backup.readAsBytes());
    GetIt.instance.get<DatabaseService>().accountsRepository.events.emit('change', TableUpdateEvent<Account>(TableUpdateEventType.UPDATE, 0)); // Emit fake event to refresh accounts
  }

  openDeleteDataConfirmationDialog(BuildContext context) async {
    var result = await utilsService.confirm(context, title: 'Eliminar todos los datos', message: '¿Estás seguro que deseas eliminar todos los datos de la aplicación?\nEsta acción no se puede deshacer, se recomienda realizar un backup antes de continuar.');
    if (result == true) {
      await GetIt.instance.get<DatabaseService>().deleteAllData();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navbar(
      title: 'Backups',
      body: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => saveBackup(context),
              child: const Text('Guardar nuevo backup', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => restoreBackup(context),
              child: const Text('Restaurar backup', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => openDeleteDataConfirmationDialog(context),
              child: const Text('Eliminar todos los datos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CupertinoColors.destructiveRed)),
            ),
          ],
        ),
      ),
    );
  }
}
