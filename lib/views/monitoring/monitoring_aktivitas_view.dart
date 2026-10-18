import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/activity_log_model.dart';
import '../../providers/activity_log_provider.dart';
import '../../widgets/app_confirm_dialog.dart';

class MonitoringAktivitasView extends StatefulWidget {
  const MonitoringAktivitasView({super.key});

  @override
  State<MonitoringAktivitasView> createState() => _MonitoringAktivitasViewState();
}

class _MonitoringAktivitasViewState extends State<MonitoringAktivitasView> {
  String _selectedFilter = 'SEMUA';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityLogProvider>().fetchLogs();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toUpperCase()) {
      case 'TAMBAH':
        return const Color(0xFF16A34A); // Muted Green
      case 'EDIT':
        return const Color(0xFF2563EB); // Slate Blue
      case 'HAPUS':
        return const Color(0xFFDC2626); // Muted Red
      case 'REFUND':
        return const Color(0xFFD97706); // Muted Amber
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityLogProvider>();
    final allLogs = provider.logs;

    final query = _searchCtrl.text.toLowerCase().trim();
    final filteredLogs = allLogs.where((log) {
      final matchesFilter = _selectedFilter == 'SEMUA' || log.actionType.toUpperCase() == _selectedFilter;
      final matchesQuery = query.isEmpty ||
          log.userName.toLowerCase().contains(query) ||
          log.title.toLowerCase().contains(query) ||
          log.details.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Monitoring Aktivitas Kasir',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
            tooltip: 'Muat Ulang Log',
            onPressed: () => provider.fetchLogs(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            tooltip: 'Bersihkan Log',
            onPressed: () async {
              final confirm = await AppConfirmDialog.show(
                context,
                title: 'Bersihkan Log Aktivitas?',
                message: 'Semua catatan aktivitas staf akan dihapus permanen dari sistem lokal.',
                confirmLabel: 'Hapus Log',
                type: ConfirmType.danger,
              );
              if (confirm == true) {
                await provider.clearAllLogs();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.fetchLogs(),
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [


                    // Search Input
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari nama staf, judul, atau rincian kegiatan...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => setState(() => _searchCtrl.clear()),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Simple Soft Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSimpleChip('SEMUA', 'Semua (${allLogs.length})'),
                          const SizedBox(width: 6),
                          _buildSimpleChip('TAMBAH', 'Tambah'),
                          const SizedBox(width: 6),
                          _buildSimpleChip('EDIT', 'Edit'),
                          const SizedBox(width: 6),
                          _buildSimpleChip('HAPUS', 'Hapus'),
                          const SizedBox(width: 6),
                          _buildSimpleChip('REFUND', 'Refund'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Clean List Items
                    if (filteredLogs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.history_rounded, size: 36, color: Color(0xFF94A3B8)),
                            SizedBox(height: 10),
                            Text(
                              'Belum ada log aktivitas kasir',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Aktivitas seperti tambah, edit, hapus data, dan refund transaksi akan tercatat secara otomatis.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          return _buildSimpleLogCard(log);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildSimpleChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLogCard(ActivityLogModel log) {
    final actionColor = _getActionColor(log.actionType);

    DateTime? dt = DateTime.tryParse(log.createdAt);
    String timeStr = log.createdAt;
    if (dt != null) {
      timeStr = DateFormat('dd/MM/yy HH:mm').format(dt);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.actionType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: actionColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    log.userName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${log.userRole.toUpperCase()})',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log.title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          if (log.details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              log.details,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
            ),
          ],
        ],
      ),
    );
  }
}
