// lib/services/backup_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:path/path.dart' as p; // For joining paths robustly
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Main import
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

class BackupService {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<File?> _createActualBackupFile() async {
    try {
      final Database db = await _dbService.database;
      final String originalDbPath = db.path;
      final File originalDbFile = File(originalDbPath);

      if (!await originalDbFile.exists()) {
        if (kDebugMode) {
          print('Original database file does not exist at: $originalDbPath');
        }
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final String backupFileName = 'insanity_tracker_backup_$timestamp.db';
      final String backupFilePath = p.join(directory.path, backupFileName);
      final File backupFile = File(backupFilePath);

      await originalDbFile.copy(backupFile.path);

      if (kDebugMode) {
        print('Backup file created at: ${backupFile.path} from $originalDbPath');
      }
      return backupFile;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error creating backup file: $e');
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }

  Future<bool> exportDatabaseViaShareSheet() async {
    try {
      final File? backupFile = await _createActualBackupFile();

      if (backupFile != null && await backupFile.exists()) {
        final xFile = XFile(backupFile.path);

        final params = ShareParams(
          text: 'Insanity Tracker Data Backup (${p.basename(backupFile.path)})',
          subject: 'Insanity Tracker Backup - ${DateTime.now().toLocal().toString().substring(0, 10)}',
          files: [xFile],
        );

        final ShareResult result = await SharePlus.instance.share(params);

        if (result.status == ShareResultStatus.success) {
          if (kDebugMode) print('Database backup shared successfully.');
          return true;
        } else if (result.status == ShareResultStatus.dismissed) {
          if (kDebugMode) print('Share sheet dismissed by user.');
          // It's not an error, but the operation wasn't completed.
          // Depending on desired behavior, you might still want to return false or a specific status.
          return false;
        } else {
          if (kDebugMode) print('Sharing failed with status: ${result.status}');
          return false;
        }
      } else {
        if (kDebugMode) print('Backup file could not be created or was not found.');
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error during database export: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  // --- NEW: Method to import database ---
  Future<bool> importDatabase() async {
    try {
      // 1. Pick the .db file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'], // Allow only .db files
      );

      if (result != null && result.files.single.path != null) {
        File pickedFile = File(result.files.single.path!);

        if (!await pickedFile.exists()) {
          if (kDebugMode) {
            print('Picked file does not exist: ${pickedFile.path}');
          }
          return false; // Or throw an error to be caught by UI
        }

        // 2. Get the path where the app's current database should be
        String appDbPath = await _dbService.getDatabasePath();

        // 3. Close current database connection (VERY IMPORTANT)
        await _dbService.close();

        // 4. Replace the current database file
        //    First, delete the old one if it exists (or rename as a backup for safety)
        File currentDbFile = File(appDbPath);
        if (await currentDbFile.exists()) {
          await currentDbFile.delete();
          if (kDebugMode) {
            print('Old database file deleted: $appDbPath');
          }
        }
        // Then, copy the picked file to the app's database location
        await pickedFile.copy(appDbPath);
        if (kDebugMode) {
          print('Database file imported from ${pickedFile.path} to $appDbPath');
        }

        // 5. Re-initialize the database connection.
        //    The DatabaseService.database getter will handle re-opening
        //    the new file on next access because we set _database to null in close().
        //    Optionally, you can call a specific reinitialize method if you prefer.
        await _dbService.reinitializeDatabase();
        if (kDebugMode) {
          print('Database re-initialized after import.');
        }

        return true;
      } else {
        // User canceled the picker or file path was null
        if (kDebugMode) {
          print('File picking canceled or no file selected.');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error importing database: $e');
        print('Stack trace: $stackTrace');
      }
      // Attempt to restore the database connection if something went wrong after closing it
      // This is a safety net.
      try {
        await _dbService.reinitializeDatabase();
        if (kDebugMode) {
          print('Database re-initialized after import error.');
        }
      } catch (reinitError) {
        if (kDebugMode) {
          print('Failed to re-initialize database after import error: $reinitError');
        }
      }
      return false;
    }
  }
}
