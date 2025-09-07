// lib/services/backup_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';

/// Service responsible for backing up and restoring the application database.
///
/// This service provides functionality to:
/// - Export database as a backup file via share sheet
/// - Import database from a backup file
/// - Handle database file operations safely
class BackupService {
  static const String _backupFilePrefix = 'insanity_tracker_backup';
  static const String _backupFileExtension = 'db';

  final DatabaseService _databaseService = DatabaseService.instance;

  /// Creates a backup file of the current database.
  ///
  /// Returns the backup [File] if successful, null otherwise.
  /// The backup file is created in the application documents directory
  /// with a timestamp in the filename.
  Future<File?> _createBackupFile() async {
    try {
      // Get database and verify it exists
      final database = await _databaseService.database;
      final originalFile = File(database.path);

      if (!await originalFile.exists()) {
        _logDebug('Database file not found at: ${database.path}');
        return null;
      }

      // Prepare backup file path
      final backupFile = await _generateBackupFile();

      // Copy database to backup location
      await originalFile.copy(backupFile.path);

      _logDebug('Backup created: ${backupFile.path}');
      return backupFile;
    } catch (e, stackTrace) {
      _logError('Failed to create backup file', e, stackTrace);
      return null;
    }
  }

  /// Generates a backup file with timestamp in the documents directory.
  Future<File> _generateBackupFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = _generateTimestamp();
    final filename = '${_backupFilePrefix}_$timestamp.$_backupFileExtension';
    return File(p.join(directory.path, filename));
  }

  /// Generates a timestamp string safe for use in filenames.
  String _generateTimestamp() {
    return DateTime.now()
        .toIso8601String()
        .split('.')[0] // Remove milliseconds
        .replaceAll(':', '-'); // Replace colons for file system compatibility
  }

  /// Exports the database via the system share sheet.
  ///
  /// Returns true if the share sheet was successfully presented,
  /// false otherwise. Note that user dismissal of the share sheet
  /// returns false as the operation wasn't completed.
  Future<bool> exportDatabase() async {
    try {
      final backupFile = await _createBackupFile();

      if (backupFile == null || !await backupFile.exists()) {
        _logDebug('Backup file creation failed or file not found');
        return false;
      }

      return await _shareBackupFile(backupFile);
    } catch (e, stackTrace) {
      _logError('Database export failed', e, stackTrace);
      return false;
    }
  }

  /// Shares the backup file using the system share sheet.
  Future<bool> _shareBackupFile(File backupFile) async {
    final xFile = XFile(backupFile.path);
    final filename = p.basename(backupFile.path);
    final dateString = DateTime.now().toLocal().toString().substring(0, 10);

    final shareParams = ShareParams(
      text: 'Insanity Tracker Data Backup ($filename)',
      subject: 'Insanity Tracker Backup - $dateString',
      files: [xFile],
    );

    final result = await SharePlus.instance.share(shareParams);

    switch (result.status) {
      case ShareResultStatus.success:
        _logDebug('Database backup shared successfully');
        return true;
      case ShareResultStatus.dismissed:
        _logDebug('Share sheet dismissed by user');
        return false;
      default:
        _logDebug('Share failed with status: ${result.status}');
        return false;
    }
  }

  /// Imports a database from a user-selected backup file.
  ///
  /// Returns true if the import was successful, false otherwise.
  /// This operation will replace the current database entirely.
  ///
  /// The process:
  /// 1. User selects a .db file
  /// 2. Current database connection is closed
  /// 3. Current database file is replaced with selected file
  /// 4. Database connection is re-initialized
  Future<bool> importDatabase() async {
    File? selectedFile;

    try {
      // Step 1: Let user select backup file
      selectedFile = await _selectBackupFile();
      if (selectedFile == null) {
        _logDebug('No backup file selected');
        return false;
      }

      // Step 2: Validate selected file
      if (!await selectedFile.exists()) {
        _logDebug('Selected backup file does not exist: ${selectedFile.path}');
        return false;
      }

      // Step 3: Replace current database
      await _replaceCurrentDatabase(selectedFile);

      // Step 4: Re-initialize database connection
      await _databaseService.reinitializeDatabase();

      _logDebug('Database import completed successfully');
      return true;
    } catch (e, stackTrace) {
      _logError('Database import failed', e, stackTrace);

      // Attempt to recover database connection
      await _attemptDatabaseRecovery();
      return false;
    }
  }

  /// Prompts user to select a backup file.
  Future<File?> _selectBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [_backupFileExtension],
    );

    if (result?.files.single.path == null) {
      return null;
    }

    return File(result!.files.single.path!);
  }

  /// Replaces the current database with the selected backup file.
  Future<void> _replaceCurrentDatabase(File backupFile) async {
    // Close current database connection first
    await _databaseService.close();

    // Get current database path and file
    final currentDbPath = await _databaseService.getDatabasePath();
    final currentDbFile = File(currentDbPath);

    // Remove existing database file if present
    if (await currentDbFile.exists()) {
      await currentDbFile.delete();
      _logDebug('Existing database file deleted');
    }

    // Copy backup file to database location
    await backupFile.copy(currentDbPath);
    _logDebug('Backup file copied to database location');
  }

  /// Attempts to recover the database connection after a failed import.
  Future<void> _attemptDatabaseRecovery() async {
    try {
      await _databaseService.reinitializeDatabase();
      _logDebug('Database connection recovered after import failure');
    } catch (e) {
      _logError('Failed to recover database connection', e);
    }
  }

  /// Logs debug messages when in debug mode.
  void _logDebug(String message) {
    if (kDebugMode) {
      //print('[BackupService] $message');
    }
  }

  /// Logs error messages with stack traces when in debug mode.
  void _logError(String message, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      /*
      print('[BackupService] ERROR: $message');
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
      */
    }
  }
}
