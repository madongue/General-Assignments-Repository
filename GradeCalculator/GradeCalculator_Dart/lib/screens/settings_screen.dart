import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/student_provider.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Language Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            title: const Text('English'),
            onTap: () {
              MyApp.setLocale(context, const Locale('en', ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language changed to English')));
            },
          ),
          ListTile(
            title: const Text('Français'),
            onTap: () {
              MyApp.setLocale(context, const Locale('fr', ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Langue changée en Français')));
            },
          ),
          const Divider(),
          const Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Provider.of<StudentProvider>(context, listen: false).clearAll();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All records cleared')));
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Clear All Records'),
          ),
        ],
      ),
    );
  }
}
