// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:insanity_tracker/providers/start_date_provider.dart';
import 'package:insanity_tracker/providers/workout_provider.dart';
import 'package:insanity_tracker/providers/fit_test_provider.dart'; // Ensure this import is present
import 'package:insanity_tracker/services/backup_service.dart';
import 'package:provider/provider.dart';
import '../providers/utils_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final startDateProvider = Provider.of<StartDateProvider>(
      context,
      listen: false,
    );
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final fitTestProvider = Provider.of<FitTestProvider>(
      context,
      listen: false,
    ); // Get the FitTestProvider
    final backupService = BackupService(); // Instantiate your service

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Program Start Date'),
            subtitle: Consumer<WorkoutProvider>(
              builder: (context, wp, child) {
                return Text(
                  wp.programStartDate == null
                      ? 'Not set'
                      : 'Current: ${UtilsProvider.formatDate(UtilsProvider.formatDateForDisplay(wp.programStartDate))}',
                );
              },
            ),
            onTap: () {
              startDateProvider.pickProgramStartDate(context, workoutProvider);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined), // Or Icons.cloud_upload
            title: const Text('Backup & Export Data'),
            subtitle: const Text('Share your app data (database file)'),
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text("Preparing export..."),
                      ],
                    ),
                  );
                },
              );

              final bool success = await backupService.exportDatabase();

              if (!context.mounted) return;
              Navigator.of(
                context,
                rootNavigator: true,
              ).pop(); // Close the loading dialog

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Share dialog initiated. Choose where to save your backup.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not initiate data export. Check logs for details.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          // --- NEW: Import Data ListTile ---
          ListTile(
            leading: const Icon(
              Icons.restore_page_outlined,
            ), // Or Icons.cloud_download
            title: const Text('Import & Restore Data'),
            subtitle: const Text('Restore data from a backup file (.db)'),
            onTap: () async {
              // Confirmation Dialog
              bool? confirmImport = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirm Import'),
                    content: const Text(
                      'This will replace your current data with the data from the selected backup file. This action cannot be undone. Are you sure?',
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                      ),
                      TextButton(
                        child: const Text(
                          'Import',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                      ),
                    ],
                  );
                },
              );

              if (confirmImport == true) {
                if (!context.mounted) return;
                // Show a loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text("Importing data..."),
                        ],
                      ),
                    );
                  },
                );

                final bool success = await backupService.importDatabase();

                if (!context.mounted) return;
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(); // Close the loading dialog

                if (success) {
                  // 1. Initialize to load data from the new DB into the provider
                  await workoutProvider.initialize();

                  // 2. Attempt to set the correct program start date based on imported data
                  bool startDateReconciled = await workoutProvider
                      .reconcileStartDateFromImportedData();
                  // 3. Initialize FitTestProvider to load its data from the new DB
                  await fitTestProvider.initialize(); // <--- This
                  // No need to call initialize() again here if reconcileStartDateFromImportedData
                  // calls setProgramStartDate which in turn calls notifyListeners or reloads.
                  // If reconcileStartDateFromImportedData *doesn't* change the date and only notifies,
                  // then the previous initialize() call is sufficient.

                  if (!context.mounted) return;

                  if (startDateReconciled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Data imported and start date reconciled successfully!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // This case means no sessions were found, or another issue.
                    // The app will likely prompt for a start date if needed.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Data imported, but start date could not be automatically set. Please check/set it manually if needed.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                  // The UI should now update correctly based on the reconciled start date
                  // and the loaded sessions from the imported database.
                } else {
                  // ... (import failed)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Data import failed. Check logs or ensure the file is a valid backup.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
