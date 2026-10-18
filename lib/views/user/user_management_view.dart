import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_confirm_dialog.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'SEMUA'; // SEMUA, ADMIN, KASIR

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('users', orderBy: 'created_at DESC');
    setState(() {
      _users = res;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchQuery.toLowerCase().trim();
    _filteredUsers = _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toUpperCase();

      final matchesQuery =
          query.isEmpty || name.contains(query) || email.contains(query);
      final matchesRole =
          _selectedRoleFilter == 'SEMUA' || role == _selectedRoleFilter;

      return matchesQuery && matchesRole;
    }).toList();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _applyFilter();
    });
  }

  void _setRoleFilter(String role) {
    setState(() {
      _selectedRoleFilter = role;
      _applyFilter();
    });
  }

  // -------------------------------------------------------------
  // -------------------------------------------------------------
  // DIALOG: TAMBAH / EDIT USER (CLEAN & MINIMAL)
  // -------------------------------------------------------------
  void _showAddEditUserDialog({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final nameCtrl = TextEditingController(text: user?['name'] ?? '');
    final emailCtrl = TextEditingController(text: user?['email'] ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = user?['role'] ?? 'KASIR';
    String selectedStatus = user?['status'] ?? 'AKTIF';
    bool obscurePass = true;
    final formKey = GlobalKey<FormState>();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isLandscape ? 8 : 20,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Akun Pengguna' : 'Tambah Pengguna Baru',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Form Body
                Flexible(
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Role Selection
                          const Text(
                            'PERAN / HAK AKSES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildRoleCard(
                                title: 'Administrator',
                                subtitle: 'Akses penuh sistem',
                                isSelected: selectedRole == 'ADMIN',
                                icon: Icons.admin_panel_settings_outlined,
                                onTap: () => setDialogState(() => selectedRole = 'ADMIN'),
                              ),
                              const SizedBox(width: 10),
                              _buildRoleCard(
                                title: 'Kasir',
                                subtitle: 'Akses penjualan POS',
                                isSelected: selectedRole == 'KASIR',
                                icon: Icons.point_of_sale_outlined,
                                onTap: () => setDialogState(() => selectedRole = 'KASIR'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Nama Lengkap
                          TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap *',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),

                          // Email
                          TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Login *',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                              if (!v.contains('@')) return 'Format email tidak valid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: passCtrl,
                            obscureText: obscurePass,
                            decoration: InputDecoration(
                              labelText: isEdit ? 'Password Baru (Opsional)' : 'Password *',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                              ),
                            ),
                            validator: (v) {
                              if (!isEdit && (v == null || v.trim().length < 6)) {
                                return 'Password minimal 6 karakter';
                              }
                              if (isEdit && v != null && v.isNotEmpty && v.trim().length < 6) {
                                return 'Password baru minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Status Switch
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedStatus == 'AKTIF' ? 'Status: Akun Aktif' : 'Status: Nonaktif',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Switch(
                                  value: selectedStatus == 'AKTIF',
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    setDialogState(() => selectedStatus = val ? 'AKTIF' : 'NONAKTIF');
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Modal Footer Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final messenger = ScaffoldMessenger.of(context);
                            final db = await DatabaseHelper.instance.database;
                            final now = DateTime.now().toIso8601String();

                            if (!isEdit) {
                              // Check duplicate email
                              final exist = await db.query(
                                'users',
                                where: 'email = ?',
                                whereArgs: [emailCtrl.text.trim().toLowerCase()],
                              );
                              if (exist.isNotEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Email sudah digunakan oleh akun lain!'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                                return;
                              }

                              final newId = 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                              await db.insert('users', {
                                'id': newId,
                                'name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim().toLowerCase(),
                                'password_hash': passCtrl.text.trim(),
                                'role': selectedRole,
                                'status': selectedStatus,
                                'created_at': now,
                              });
                            } else {
                              final Map<String, dynamic> updateData = {
                                'name': nameCtrl.text.trim(),
                                'email': emailCtrl.text.trim().toLowerCase(),
                                'role': selectedRole,
                                'status': selectedStatus,
                              };
                              if (passCtrl.text.trim().isNotEmpty) {
                                updateData['password_hash'] = passCtrl.text.trim();
                              }

                              await db.update(
                                'users',
                                updateData,
                                where: 'id = ?',
                                whereArgs: [user['id']],
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              _loadUsers();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Data pengguna berhasil diperbarui'
                                        : 'Pengguna baru berhasil ditambahkan',
                                  ),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                          child: Text(
                            isEdit ? 'Simpan' : 'Tambah',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE6F4F1) : const Color(0xFFFFFFFF),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isSelected ? AppColors.primaryDark : const Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // DIALOG: RESET PASSWORD CEPAT
  // -------------------------------------------------------------
  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passCtrl = TextEditingController();
    bool obscure = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ganti Password',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Akun: ${user['name']} (${user['email']})',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password Baru *',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().length < 6 ? 'Password minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final db = await DatabaseHelper.instance.database;
                            await db.update(
                              'users',
                              {'password_hash': passCtrl.text.trim()},
                              where: 'id = ?',
                              whereArgs: [user['id']],
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Password untuk ${user['name']} berhasil diubah'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // DIALOG: KONFIRMASI HAPUS
  // -------------------------------------------------------------
  void _confirmDeleteUser(Map<String, dynamic> user, String currentUserId) async {
    if (user['id'] == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat menghapus akun Anda sendiri saat sedang login!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Hapus Akun Pengguna?',
      message: 'Akun ini akan dihapus permanen dari sistem.',
      itemName: '${user['name']} (${user['email']})',
      confirmLabel: 'Ya, Hapus',
      type: ConfirmType.danger,
    );

    if (confirm == true && mounted) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [user['id']],
      );
      if (mounted) {
        _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun ${user['name']} telah dihapus'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final adminCount = _users
        .where((u) => (u['role'] ?? '').toString().toUpperCase() == 'ADMIN')
        .length;
    final kasirCount = _users
        .where((u) => (u['role'] ?? '').toString().toUpperCase() == 'KASIR')
        .length;


    final isTablet = ResponsiveLayout.isTabletOrLarger(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS || isLandscape)
          ? FloatingActionButton.extended(
              heroTag: 'fab_user',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddEditUserDialog(),
            )
          : FloatingActionButton(
              heroTag: 'fab_user',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Tambah Pengguna',
              onPressed: () => _showAddEditUserDialog(),
              child: const Icon(Icons.add_rounded),
            ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: Scrollbar(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            isLandscape ? 12 : 20,
            20,
            isLandscape ? 16 : (isTablet ? 24 : 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // Search Bar
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email pengguna...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterRoleChip(
                      'SEMUA',
                      'Semua Akun (${_users.length})',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterRoleChip(
                      'ADMIN',
                      'Admin ($adminCount)',
                      icon: Icons.security,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterRoleChip(
                      'KASIR',
                      'Kasir ($kasirCount)',
                      icon: Icons.point_of_sale,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // User List
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredUsers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 54,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak ada pengguna ditemukan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Coba ubah kata kunci pencarian atau filter peran',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final u = _filteredUsers[idx];
                    final isSelf = u['id'] == currentUserId;
                    final isAktif =
                        (u['status'] ?? '').toString().toUpperCase() == 'AKTIF';

                    return Card(
                      elevation: 0.8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelf
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : isAktif
                              ? AppColors.border
                              : AppColors.danger.withValues(alpha: 0.3),
                          width: isSelf ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Avatar, Name, Role Badge, Menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              u['name'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSelf)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFE2E8F0),
                                                  borderRadius: BorderRadius.all(Radius.circular(6)),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                                  child: Text(
                                                    'Anda',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.email_outlined,
                                            size: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              u['email'] ?? '-',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
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

                                // Actions Popup Menu
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (val) {
                                    switch (val) {
                                      case 'edit':
                                        _showAddEditUserDialog(user: u);
                                        break;
                                      case 'reset_pass':
                                        _showResetPasswordDialog(u);
                                        break;
                                      case 'toggle_status':
                                        _toggleUserStatus(u, currentUserId);
                                        break;
                                      case 'delete':
                                        _confirmDeleteUser(u, currentUserId);
                                        break;
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Edit Data'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reset_pass',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.lock_reset,
                                            size: 18,
                                            color: AppColors.warning,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Ganti Password'),
                                        ],
                                      ),
                                    ),
                                    if (!isSelf)
                                      PopupMenuItem(
                                        value: 'toggle_status',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isAktif
                                                  ? Icons.block_outlined
                                                  : Icons.check_circle_outline,
                                              size: 18,
                                              color: isAktif
                                                  ? AppColors.danger
                                                  : AppColors.success,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              isAktif
                                                  ? 'Nonaktifkan Akun'
                                                  : 'Aktifkan Akun',
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (!isSelf)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.danger,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Hapus Akun',
                                              style: TextStyle(
                                                color: AppColors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80), // space for FAB
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(
    Map<String, dynamic> user,
    String currentUserId,
  ) async {
    if (user['id'] == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat menonaktifkan akun Anda sendiri!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final newStatus = (user['status'] ?? 'AKTIF') == 'AKTIF'
        ? 'NONAKTIF'
        : 'AKTIF';
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'users',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [user['id']],
    );
    _loadUsers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status akun ${user['name']} diubah menjadi $newStatus',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }



  Widget _buildFilterRoleChip(String role, String label, {IconData? icon}) {
    final isSelected = _selectedRoleFilter == role;
    return InkWell(
      onTap: () => _setRoleFilter(role),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
