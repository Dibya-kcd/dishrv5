import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import 'printer_settings_screen.dart';
import 'role_config_screen.dart';
import 'admin_panel_screen.dart';
import 'firebase_debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedSection = 'printer';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final isAdmin = provider.realRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      drawer: _buildDrawer(isAdmin, provider),
      body: _buildBody(),
    );
  }

  Widget _buildDrawer(bool isAdmin, RestaurantProvider provider) {
    return Drawer(
      backgroundColor: const Color(0xFF18181B),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0B0B0E),
              border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    isAdmin ? 'ADMIN SETTINGS' : 'STAFF SETTINGS',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.print,
            label: 'Printer Settings',
            id: 'printer',
          ),
          if (isAdmin) ...[
            _buildDrawerItem(
              icon: Icons.security,
              label: 'Role & Permission',
              id: 'roles',
            ),
            _buildDrawerItem(
              icon: Icons.theater_comedy,
              label: 'Role Play',
              id: 'simulation',
            ),
            _buildDrawerItem(
              icon: Icons.bug_report,
              label: 'System Diagnostics',
              id: 'debug',
            ),
          ],
          const Spacer(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String label, required String id}) {
    final isSelected = _selectedSection == id;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF3B82F6) : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
      onTap: () {
        setState(() => _selectedSection = id);
        Navigator.pop(context); // Close drawer
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedSection) {
      case 'printer':
        return const PrinterSettingsScreen(embed: true);
      case 'roles':
        return const RoleManagementScreen(embed: true);
      case 'simulation':
        return const AdminPanelScreen(embed: true);
      case 'debug':
        return const FirebaseDebugScreen(embed: true);
      default:
        return const Center(child: Text('Select an option from the menu', style: TextStyle(color: Colors.white)));
    }
  }
}
