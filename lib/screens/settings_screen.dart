import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/app_ui_kit.dart';
import 'printer_settings_screen.dart';
import 'role_config_screen.dart';
import 'admin_panel_screen.dart';
import 'firebase_debug_screen.dart';
import 'tax_settings_screen.dart';
import '../data/sync_service.dart';
import 'tables_screen.dart';
import 'employee_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Section model
// ─────────────────────────────────────────────────────────────────────────────

enum _Access { all, managerUp, adminOnly }

class _NavItem {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  final _Access access;

  const _NavItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
    this.access = _Access.all,
  });
}

const _kSections = <_NavItem>[
  // ── Operations ────────────────────────────────────────────
  _NavItem(
    id: 'tables_manage',
    icon: Icons.table_restaurant_outlined,
    label: 'Floor Plan',
    subtitle: 'Configure tables, numbers & seat capacity',
    access: _Access.managerUp,
  ),
  _NavItem(
    id: 'employees',
    icon: Icons.badge_outlined,
    label: 'Team',
    subtitle: 'Staff records, roles & access control',
    access: _Access.managerUp,
  ),

  // ── Finance ───────────────────────────────────────────────
  _NavItem(
    id: 'tax',
    icon: Icons.receipt_long_outlined,
    label: 'Tax & Billing',
    subtitle: 'GST rate, label and price-inclusive mode',
  ),

  // ── Hardware ──────────────────────────────────────────────
  _NavItem(
    id: 'printer',
    icon: Icons.print_outlined,
    label: 'Printers',
    subtitle: 'Bluetooth, network & USB receipt printers',
  ),

  // ── Access control (admin only) ───────────────────────────
  _NavItem(
    id: 'roles',
    icon: Icons.shield_outlined,
    label: 'Permissions',
    subtitle: 'Define what each role can see and do',
    access: _Access.adminOnly,
  ),
  _NavItem(
    id: 'simulation',
    icon: Icons.theater_comedy_outlined,
    label: 'Role Preview',
    subtitle: 'Preview the app as any user role',
    access: _Access.adminOnly,
  ),

  // ── System (admin only) ───────────────────────────────────
  _NavItem(
    id: 'sync',
    icon: Icons.cloud_sync_outlined,
    label: 'Sync & Data',
    subtitle: 'Firebase connection, sync & data reset',
    access: _Access.adminOnly,
  ),
  _NavItem(
    id: 'debug',
    icon: Icons.monitor_heart_outlined,
    label: 'Diagnostics',
    subtitle: 'System health, connection logs & debug',
    access: _Access.adminOnly,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  /// If set, open directly to that section id on load.
  final String? initialSection;
  const SettingsScreen({super.key, this.initialSection});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late List<_NavItem> _visible;
  late TabController _tabController;

  bool _canSee(_NavItem s, String role) {
    switch (s.access) {
      case _Access.adminOnly:  return role == 'admin';
      case _Access.managerUp:  return role == 'admin' || role == 'manager';
      case _Access.all:        return true;
    }
  }

  List<_NavItem> _buildVisible() {
    final role = (context.read<RestaurantProvider>().realRole ?? '').toLowerCase();
    return _kSections.where((s) => _canSee(s, role)).toList();
  }

  int _initialIndex() {
    if (widget.initialSection == null) return 0;
    final i = _visible.indexWhere((s) => s.id == widget.initialSection);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _visible = _buildVisible();
    _tabController = TabController(
      length: _visible.length,
      vsync: this,
      initialIndex: _initialIndex(),
    );
  }

  void _refreshVisible() {
    final next = _buildVisible();
    if (next.length != _visible.length) {
      final idx = _tabController.index.clamp(0, next.length - 1);
      _tabController.dispose();
      _visible = next;
      _tabController = TabController(
          length: _visible.length, vsync: this, initialIndex: idx);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _paneFor(String id) {
    switch (id) {
      case 'tables_manage': return const TableManagementScreen();
      case 'employees':     return const EmployeeScreen();
      case 'tax':           return const TaxSettingsScreen(embed: true);
      case 'printer':       return const PrinterSettingsScreen(embed: true);
      case 'roles':         return const RoleManagementScreen(embed: true);
      case 'simulation':    return const AdminPanelScreen(embed: true);
      case 'sync':          return const _SyncPane();
      case 'debug':         return const FirebaseDebugScreen(embed: true);
      default:
        return const Center(
          child: Text('Select a section',
              style: TextStyle(color: AppColors.textSecondary)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<RestaurantProvider>();
    _refreshVisible();

    return LayoutBuilder(builder: (_, c) {
      return c.maxWidth >= 720 ? _wideLayout() : _narrowLayout();
    });
  }

  // ── Wide: sidebar + detail pane ───────────────────────────────────────────
  Widget _wideLayout() {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: Row(children: [
        _Sidebar(sections: _visible, tabController: _tabController),
        const VerticalDivider(width: 1, color: AppColors.border),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: _visible.map((s) => _paneFor(s.id)).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Narrow: icon+label tab bar across top ─────────────────────────────────
  Widget _narrowLayout() {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        elevation: 0,
        titleSpacing: 16,
        title: const Text('Settings', style: AppTextStyles.h2),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: ColoredBox(
            color: AppColors.bg1,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.amber,
              indicatorWeight: 2.5,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: _visible
                  .map((s) => Tab(
                        height: 42,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.icon, size: 15),
                            const SizedBox(width: 5),
                            Text(s.label),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: _visible.map((s) => _paneFor(s.id)).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar (wide layout)
// ─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<_NavItem> sections;
  final TabController tabController;
  const _Sidebar({required this.sections, required this.tabController});

  // Group labels by section clusters
  static const _groupLabels = <String, String>{
    'tables_manage': 'Operations',
    'tax':           'Finance',
    'printer':       'Hardware',
    'roles':         'Access',
    'sync':          'System',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: AppColors.bg1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text('Settings', style: AppTextStyles.h1),
            ),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedBuilder(
                animation: tabController,
                builder: (_, __) {
                  final items = <Widget>[];
                  String? lastGroup;

                  for (var i = 0; i < sections.length; i++) {
                    final s = sections[i];
                    final group = _groupLabels[s.id];
                    if (group != null && group != lastGroup) {
                      lastGroup = group;
                      if (items.isNotEmpty) {
                        items.add(const Divider(
                            color: AppColors.border,
                            height: 1,
                            indent: 16,
                            endIndent: 16));
                      }
                      items.add(Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 10, 20, 4),
                        child: Text(
                          group.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ));
                    }

                    final sel = tabController.index == i;
                    items.add(AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.amber.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        leading: Icon(s.icon,
                            size: 18,
                            color: sel
                                ? AppColors.amber
                                : AppColors.textSecondary),
                        title: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: sel
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          s.subtitle,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => tabController.animateTo(i),
                      ),
                    ));
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: items,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync & Data pane (new — consolidates data reset + Firebase connection)
// ─────────────────────────────────────────────────────────────────────────────

class _SyncPane extends StatelessWidget {
  const _SyncPane();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section: Firebase sync ─────────────────────────────────
            const SectionHeader('Firebase Sync'),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: SyncService.instance.connected,
                      builder: (_, connected, __) => Row(children: [
                        Icon(Icons.circle,
                            size: 10,
                            color: connected
                                ? AppColors.green
                                : AppColors.red),
                        const SizedBox(width: 8),
                        Text(
                          connected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                              color: connected
                                  ? AppColors.green
                                  : AppColors.red,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  AppButton.primary(
                    'Force Sync Now',
                    icon: Icons.sync,
                    onPressed: () async {
                      try {
                        await SyncService.instance.initialUpload();
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sync triggered')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section: Danger zone ───────────────────────────────────
            const SectionHeader('Danger Zone'),
            const SizedBox(height: 12),
            AppCard(
              borderColor: AppColors.red.withValues(alpha: 0.4),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reset All Local Data',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Wipes all local data and re-seeds defaults. '
                    'Firebase data is not affected.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  AppButton.danger(
                    'Reset Local Data',
                    icon: Icons.delete_forever_outlined,
                    onPressed: () => _confirmReset(context, provider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(
      BuildContext context, RestaurantProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Reset All Local Data?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will delete all local orders, tables, menu items '
          'and settings, then re-seed the defaults. '
          'It cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          AppButton.danger(
            'Reset',
            onPressed: () {
              Navigator.pop(context);
              provider.resetAllDataFresh(context);
            },
          ),
        ],
      ),
    );
  }
}
