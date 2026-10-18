import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/responsive_layout.dart';
import '../providers/auth_provider.dart';
import 'dashboard/dashboard_view.dart';
import 'kasir/kasir_view.dart';
import 'produk/produk_view.dart';
import 'riwayat/riwayat_view.dart';
import 'laporan/laporan_view.dart';
import 'supplier/supplier_view.dart';
import 'user/user_management_view.dart';
import 'monitoring/monitoring_aktivitas_view.dart';
import 'auth/login_view.dart';
import 'kedaluwarsa/kedaluwarsa_view.dart';
import '../widgets/app_confirm_dialog.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final List<int> _navHistory = [];
  bool _isSidebarOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auto-update check removed
    });
  }

  final List<String> _titles = [
    'Dashboard',
    'Kasir (Point of Sale)',
    'Manajemen Produk & Stok',
    'Monitoring Kedaluwarsa',
    'Riwayat Transaksi',
    'Laporan Penjualan',
    'Distributor & Supplier',
    'Kelola Pengguna & Staf',
    'Menu profil',
  ];

  void _onNavigate(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _navHistory.add(_selectedIndex);
      _selectedIndex = index;
    });
  }

  void _handleLogout(AuthProvider auth) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Keluar dari Akun?',
      message: 'Sesi Anda akan diakhiri dan harus login kembali untuk masuk.',
      confirmLabel: 'Ya, Keluar',
      icon: Icons.logout_rounded,
      type: ConfirmType.danger,
    );

    if (confirm == true) {
      await auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginView(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTablet = ResponsiveLayout.isTabletOrLarger(context);

    final List<Widget> pages = [
      DashboardView(onNavigate: _onNavigate),
      const KasirView(),
      const ProdukView(),
      const KedaluwarsaView(),
      const RiwayatView(),
      const LaporanView(),
      const SupplierView(),
      const UserManagementView(),
      _buildMenuPage(context, auth),
    ];

    Widget content;
    if (isTablet) {
      final isCompactLandscape = MediaQuery.of(context).orientation == Orientation.landscape &&
          MediaQuery.of(context).size.shortestSide < 600;

      // -------------------------------------------------------------
      // TABLET LAYOUT: Permanent Navigation Rail
      // -------------------------------------------------------------
      content = Scaffold(
        body: Row(
          children: [
            // Left Navigation Rail (Clean Modern Sidebar)
            if (_isSidebarOpen)
            Container(
              width: isCompactLandscape ? 220 : 250,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Column(
                children: [
                  // App Brand & User Profile Header
                  Container(
                    padding: isCompactLandscape
                        ? const EdgeInsets.fromLTRB(16, 16, 16, 12)
                        : const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/images/apotek-logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.local_pharmacy_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Apotek Tia',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sistem POS & Kasir',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // User Profile Card
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  auth.currentUser?.name.isNotEmpty == true
                                      ? auth.currentUser!.name.substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.currentUser?.name ?? 'Petugas Apotek',
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      auth.currentUser?.role ?? 'KASIR',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  // Navigation Items List
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      children: [
                        _buildNavItem(0, 'Dashboard', Icons.grid_view_outlined, Icons.grid_view_rounded),
                        _buildNavItem(1, 'Kasir (POS)', Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
                        _buildNavItem(2, 'Produk & Stok', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
                        _buildNavItem(3, 'Monitoring Kedaluwarsa', Icons.edit_calendar_outlined, Icons.edit_calendar_rounded),
                        _buildNavItem(4, 'Riwayat Transaksi', Icons.receipt_outlined, Icons.receipt_rounded),
                        _buildNavItem(5, 'Laporan Penjualan', Icons.analytics_outlined, Icons.analytics_rounded),
                        _buildNavItem(6, 'Distributor & Supplier', Icons.local_shipping_outlined, Icons.local_shipping_rounded),
                        if (auth.currentUser?.isAdmin == true) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              'ADMINISTRASI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          _buildNavItem(7, 'Kelola Pengguna', Icons.manage_accounts_outlined, Icons.manage_accounts_rounded),
                        ],
                      ],
                    ),
                  ),
                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: InkWell(
                      onTap: () => _handleLogout(auth),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text(
                              'Keluar dari Akun',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Header Topbar
                  Container(
                    height: isCompactLandscape ? 50 : 64,
                    padding: EdgeInsets.symmetric(horizontal: isCompactLandscape ? 16 : 24),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(_isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded),
                              color: AppColors.textPrimary,
                              onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                            ),
                            const SizedBox(width: 8),
                            Text(
                          _titles[_selectedIndex],
                          style: TextStyle(
                            fontSize: isCompactLandscape ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // -------------------------------------------------------------
      // MOBILE LAYOUT: Top AppBar + Bottom Navigation + Drawer
      // -------------------------------------------------------------
      content = Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Image.asset(
                'assets/images/apotek-logo.png',
                height: 24,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                _titles[_selectedIndex],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          actions: [],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: MediaQuery.of(context).orientation == Orientation.landscape
            ? null
            : _buildModernBottomNav(context, auth),
      );
    }

    return PopScope(
      canPop: _navHistory.isEmpty && _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_navHistory.isNotEmpty) {
          setState(() {
            _selectedIndex = _navHistory.removeLast();
          });
        } else if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: content,
    );
  }

  // ─── Halaman Menu Profil & Navigasi Lainnya ────────────────────────────────
  Widget _buildMenuPage(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    final initial = user != null && user.name.isNotEmpty
        ? user.name.substring(0, 1).toUpperCase()
        : 'U';
    final isAdmin = user?.isAdmin == true;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // 1. Profil Pengguna Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Petugas Apotek',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user?.role ?? 'KASIR',
                              style: TextStyle(
                                color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user?.email.isNotEmpty == true ? user!.email : 'Apotek Tia Farma',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Section: OPERASIONAL & LAPORAN
          _buildMenuSectionHeader('OPERASIONAL & LAPORAN'),
          const SizedBox(height: 8),
          _buildMenuCardItem(
            index: 3,
            title: 'Monitoring Kedaluwarsa',
            subtitle: 'Pantau obat mendekati expired & stok kritis',
            icon: Icons.event_busy_rounded,
          ),
          _buildMenuCardItem(
            index: 5,
            title: 'Laporan Penjualan',
            subtitle: 'Grafik transaksi, rekap laba & omset',
            icon: Icons.insert_chart_outlined_rounded,
          ),
          _buildMenuCardItem(
            index: 6,
            title: 'Distributor & Supplier',
            subtitle: 'Daftar pemasok obat & faktur barang',
            icon: Icons.local_shipping_outlined,
          ),

          const SizedBox(height: 18),

          // 3. Section: SISTEM & PENGATURAN
          _buildMenuSectionHeader('SISTEM & PENGATURAN'),
          const SizedBox(height: 8),
          if (isAdmin) ...[
            _buildMenuCardItem(
              index: 7,
              title: 'Kelola Pengguna & Staf',
              subtitle: 'Manajemen akun petugas, kasir & hak akses',
              icon: Icons.manage_accounts_outlined,
            ),
            _buildMenuCardItem(
              index: -1,
              title: 'Monitoring Aktivitas Kasir',
              subtitle: 'Pengawasan realtime aksi kasir',
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF0F172A),
              iconBg: const Color(0xFFF1F5F9),
              customTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MonitoringAktivitasView()),
                );
              },
            ),
          ],


          const SizedBox(height: 24),

          // 4. Tombol Logout (Abu-abu, Teks & Ikon Hitam, Tanpa Warna Merah)
          InkWell(
            onTap: () => _handleLogout(auth),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    'Keluar dari Akun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMenuSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildMenuCardItem({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    Color iconColor = const Color(0xFF334155),
    Color iconBg = const Color(0xFFF1F5F9),
    VoidCallback? customTap,
    Widget? trailing,
  }) {
    final isSelected = index >= 0 && _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: customTap ?? () => _onNavigate(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }




  Widget _buildModernBottomNav(BuildContext context, AuthProvider auth) {
    return ColoredBox(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildModernNavItem(
                  index: 0,
                  title: 'Dashboard',
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                ),
                _buildModernNavItem(
                  index: 1,
                  title: 'Kasir',
                  icon: Icons.shopping_bag_outlined,
                  activeIcon: Icons.shopping_bag_rounded,
                  isHighlight: true,
                ),
                _buildModernNavItem(
                  index: 2,
                  title: 'Produk',
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                ),
                _buildModernNavItem(
                  index: 4,
                  title: 'Riwayat',
                  icon: Icons.receipt_outlined,
                  activeIcon: Icons.receipt_rounded,
                ),
                // Tombol Menu / Profil
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _onNavigate(8);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: (_selectedIndex == 3 || _selectedIndex >= 5) ? const Color(0xFFE6F4F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: (_selectedIndex == 3 || _selectedIndex >= 5) ? AppColors.primary : const Color(0xFF94A3B8),
                              child: Text(
                                auth.currentUser?.name.isNotEmpty == true
                                    ? auth.currentUser!.name.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Profil',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: (_selectedIndex == 3 || _selectedIndex >= 5) ? FontWeight.w700 : FontWeight.w500,
                                color: (_selectedIndex == 3 || _selectedIndex >= 5) ? AppColors.primaryDark : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem({
    required int index,
    required String title,
    required IconData icon,
    required IconData activeIcon,
    bool isHighlight = false,
    bool isDrawer = false,
  }) {
    final bool isSelected = isDrawer ? _selectedIndex >= 4 : _selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            if (isDrawer) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              _onNavigate(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE6F4F1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 21,
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, IconData activeIcon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _onNavigate(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppColors.primaryDark : const Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

