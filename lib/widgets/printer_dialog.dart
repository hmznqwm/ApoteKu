import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal_plus/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/transaksi_model.dart';
import '../services/printer_service.dart';
import '../core/theme/app_theme.dart';

const MethodChannel _nativeBtChannel = MethodChannel('com.antikafarma.apotek_app/bluetooth');

class PrinterConnectDialog extends StatefulWidget {
  final VoidCallback? onConnected;

  const PrinterConnectDialog({super.key, this.onConnected});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PrinterConnectDialog(),
    );
  }

  @override
  State<PrinterConnectDialog> createState() => _PrinterConnectDialogState();
}

class _PrinterConnectDialogState extends State<PrinterConnectDialog> with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isChecking = true;
  bool _isConnected = false;
  bool _isBluetoothOn = false;
  String? _connectedName;
  List<BluetoothInfo> _devices = [];
  String? _connectingMac;
  String _statusMessage = '';
  String _selectedPaperSize = '58';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPaperSize();
    _requestPermissionAndCheck();
  }

  Future<void> _loadPaperSize() async {
    final size = await PrinterService.instance.getPaperSize();
    if (mounted) {
      setState(() {
        _selectedPaperSize = size == PaperSize.mm80 ? '80' : '58';
      });
    }
  }

  Future<void> _handlePaperSizeChanged(String? newSize) async {
    if (newSize == null) return;
    setState(() => _selectedPaperSize = newSize);
    await PrinterService.instance.setPaperSize(newSize);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestPermissionAndCheck();
    }
  }

  /// Request Bluetooth & Location permissions natively and check adapter status
  Future<void> _requestPermissionAndCheck() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Memeriksa izin & koneksi Bluetooth...';
    });

    // 1. Trigger native Android system pop-up to turn on Bluetooth radio if off
    try {
      await _nativeBtChannel.invokeMethod('requestEnableBluetooth');
    } catch (e) {
      debugPrint('Error requesting native Bluetooth enable: $e');
    }

    // 2. Request native permission popups directly
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    // Check if bluetooth adapter is turned on
    bool btEnabled = false;
    try {
      btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('Error checking bluetooth adapter: $e');
    }

    final connected = await PrinterService.instance.checkConnection();
    final savedName = await PrinterService.instance.getSavedPrinterName();

    List<BluetoothInfo> devices = [];
    if (btEnabled) {
      devices = await PrinterService.instance.getBondedDevices();
    }

    if (mounted) {
      setState(() {
        _isChecking = false;
        _isBluetoothOn = btEnabled;
        _isConnected = connected;
        _connectedName = PrinterService.instance.connectedName ?? savedName;
        _devices = devices;
        _statusMessage = !btEnabled
            ? 'Bluetooth belum aktif. Silakan nyalakan sakelar Bluetooth di HP Anda!'
            : (!connected
                ? 'Printer belum terhubung. Silakan pilih printer Bluetooth atau gunakan port USB.'
                : 'Printer terhubung dan siap digunakan.');
      });
    }
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() {
      _isLoading = true;
      _connectingMac = device.macAdress;
      _statusMessage = 'Menghubungkan ke ${device.name}...';
    });

    final success = await PrinterService.instance.connect(
      device.macAdress,
      name: device.name,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _connectingMac = null;
        _isConnected = success;
        _connectedName = device.name;
        _statusMessage = success
            ? 'Berhasil terhubung ke ${device.name}'
            : 'Gagal terhubung ke ${device.name}';
      });

      if (success) {
        widget.onConnected?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil terhubung ke printer ${device.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await PrinterService.instance.disconnect();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
        _connectedName = null;
        _statusMessage = 'Printer terputus';
      });
    }
  }

  Future<void> _reconnectSaved() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Mencoba menyambungkan ke printer...';
    });

    final success = await PrinterService.instance.autoConnect();

    final savedName = await PrinterService.instance.getSavedPrinterName();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isConnected = success;
        _connectedName = PrinterService.instance.connectedName ?? savedName;
        _statusMessage = success
            ? 'Berhasil terhubung ke ${_connectedName ?? 'Printer'}'
            : 'Gagal menyambungkan ulang. Pastikan printer menyala & dekat dengan HP.';
      });

      if (success) {
        widget.onConnected?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil terhubung ke printer ${_connectedName ?? ''}'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        _requestPermissionAndCheck();
      }
    }
  }

  Future<void> _testPrintBluetooth() async {
    setState(() => _isLoading = true);
    final ok = await PrinterService.instance.printTestReceipt();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Tes cetak Bluetooth berhasil!'
              : 'Gagal mencetak tes Bluetooth. Periksa koneksi printer.'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _testPrintUsb() async {
    // Generate dummy transaction for testing USB / system print
    final dummyTrx = TransaksiModel(
      id: 'TES-001',
      invoice: '2201-00106',
      tanggal: DateTime.now().toIso8601String().substring(0, 10),
      kasirEmail: 'admin@apotek.com',
      kasirName: 'Admin',
      subtotal: 54000,
      diskon: 0,
      total: 54000,
      bayar: 60000,
      kembalian: 6000,
      createdAt: DateTime.now().toIso8601String(),
      details: [
        TransaksiDetailModel(
          id: '1',
          transaksiId: 'TES-001',
          invoice: '2201-00106',
          produkId: 'P1',
          kode: 'ALK01',
          nama: 'Alkohol 70% 300ml',
          qty: 1,
          harga: 18000,
          subtotal: 18000,
        ),
        TransaksiDetailModel(
          id: '2',
          transaksiId: 'TES-001',
          invoice: '2201-00106',
          produkId: 'P2',
          kode: 'AMB01',
          nama: 'Ambeven',
          qty: 2,
          harga: 18000,
          subtotal: 36000,
        ),
      ],
    );

    await PrinterService.instance.printUsbOrSystemReceipt(dummyTrx);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final maxDialogHeight = MediaQuery.of(context).size.height * (isLandscape ? 0.94 : 0.88);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: maxDialogHeight),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan Printer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Koneksi Bluetooth / USB & Ukuran Thermal',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context, _isConnected),
                ),
              ],
            ),
            const Divider(height: 18),

            // Paper Size Selection Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_size_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ukuran Kertas Thermal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '58mm (standar kasir/portable) atau 80mm',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedPaperSize,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: '58',
                        child: Text('58 mm (32 col)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: '80',
                        child: Text('80 mm (48 col)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: _handlePaperSizeChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // USB Connection Info Tip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.usb_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Untuk USB / OTG / Kabel data, gunakan tombol "USB / Dokumen" saat mencetak.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _testPrintUsb,
                    child: const Text('Tes USB', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bluetooth OFF / No Permission Banner
            if (!_isBluetoothOn) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, color: Colors.amber.shade900, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bluetooth Belum Aktif',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const Text(
                                'Aktifkan Bluetooth & Izinkan perangkat untuk printer wireless.',
                                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        ),
                        onPressed: _requestPermissionAndCheck,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_searching_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Nyalakan Bluetooth & Izinkan',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Connection Status Card
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isConnected
                    ? AppColors.success.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isConnected
                      ? AppColors.success.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected
                        ? Icons.check_circle_rounded
                        : Icons.bluetooth_searching_rounded,
                    color: _isConnected ? AppColors.success : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? 'Bluetooth Terhubung' : 'Bluetooth Belum Terhubung',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _isConnected ? AppColors.success : Colors.orange.shade800,
                          ),
                        ),
                        if (_connectedName != null)
                          Text(
                            _connectedName!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (_isConnected) ...[
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: _isLoading ? null : _disconnect,
                      child: const Text('Putus', style: TextStyle(fontSize: 10.5)),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _isLoading ? null : _reconnectSaved,
                      icon: const Icon(Icons.sync_rounded, size: 13),
                      label: const Text('Sambung Ulang', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 10.5, color: AppColors.primary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),

            // Section Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Perangkat Bluetooth Terdaftar:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _isChecking ? null : _requestPermissionAndCheck,
                  tooltip: 'Segarkan Perangkat',
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Devices List Area
            Expanded(
              child: _isChecking
                  ? const Center(child: CircularProgressIndicator())
                  : _devices.isEmpty
                      ? SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bluetooth_disabled_rounded, size: 28, color: AppColors.textMuted),
                                const SizedBox(height: 4),
                                Text(
                                  _isBluetoothOn
                                      ? 'Tidak ada printer Bluetooth paired.'
                                      : 'Bluetooth tidak aktif.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Silakan pairing printer thermal di pengaturan Bluetooth HP terlebih dahulu.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _devices.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isConnectingThis = _connectingMac == device.macAdress;

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.print_outlined, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.name.isEmpty ? 'Thermal Printer' : device.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          device.macAdress,
                                          style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: (_isLoading || isConnectingThis)
                                        ? null
                                        : () => _connectToDevice(device),
                                    child: isConnectingThis
                                        ? const SizedBox(
                                            height: 12,
                                            width: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Hubungkan', style: TextStyle(fontSize: 10.5)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 10),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (_isConnected)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 15),
                    label: const Text('Tes Bluetooth', style: TextStyle(fontSize: 11)),
                    onPressed: _isLoading ? null : _testPrintBluetooth,
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  onPressed: () => Navigator.pop(context, _isConnected),
                  child: const Text('Tutup', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
