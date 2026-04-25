import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import '../models/vehicle_model.dart';
import '../utils/constants.dart';

class VehicleDetailScreen extends StatefulWidget {
  final VehicleModel vehicle;
  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final GlobalKey _stickerKey = GlobalKey();
  bool _downloading = false;

  // QR encodes Firebase Hosting URL — reads from the same Firebase database
  String get _qrData => 'https://park-13c37.web.app/v/${widget.vehicle.token}';

  Future<void> _makeCall() async {
    final uri = Uri.parse('tel:${widget.vehicle.callNumber}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp() async {
    final number = widget.vehicle.whatsappNumber.isNotEmpty
        ? widget.vehicle.whatsappNumber
        : widget.vehicle.callNumber;
    final clean = number.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
        'https://wa.me/$clean?text=Hi, I need to reach you regarding your vehicle ${widget.vehicle.vehicleNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadSticker() async {
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Wait for the widget to fully render before capturing
      await Future.delayed(const Duration(milliseconds: 200));
      final boundary = _stickerKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find sticker widget');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final bytes = byteData.buffer.asUint8List();

      final name =
          widget.vehicle.vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'SecurePark_$name';

      // Save directly to device Gallery
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: '$fileName.png',
        androidRelativePath: 'Pictures/SecurePark',
        skipIfExists: false,
      );

      if (result.isSuccess) {
        messenger.showSnackBar(const SnackBar(
          content: Text('✅ QR sticker saved to Gallery!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
      } else {
        // Fallback: write directly to public Downloads folder
        // (/storage/emulated/0/Download/) — visible in Files app on all devices
        const downloadsPath = '/storage/emulated/0/Download';
        final dir = Directory(downloadsPath);
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('$downloadsPath/$fileName.png');
        await file.writeAsBytes(bytes);
        messenger.showSnackBar(const SnackBar(
          content: Text('✅ QR sticker saved to Downloads folder!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Download failed: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.primary),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'QR Sticker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white),
                      tooltip: 'Copy QR link',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _qrData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR link copied to clipboard!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _stickerKey,
                    child: _QrSticker(
                        vehicle: widget.vehicle, qrData: _qrData),
                  ),

                  const SizedBox(height: 16),

                  // Download Sticker button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloading ? null : _downloadSticker,
                      icon: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download,
                              color: Colors.white),
                      label: Text(
                        _downloading
                            ? 'Preparing...'
                            : 'Download Sticker',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contact Actions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Call button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _makeCall,
                            icon: const Icon(Icons.phone, color: Colors.white),
                            label: Text(
                              'Call  ${widget.vehicle.callNumber}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // WhatsApp button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.message,
                                color: Colors.white),
                            label: Text(
                              'WhatsApp  ${widget.vehicle.whatsappNumber.isNotEmpty ? widget.vehicle.whatsappNumber : widget.vehicle.callNumber}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Vehicle Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Info',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Vehicle Number',
                          value: widget.vehicle.vehicleNumber,
                        ),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Call Number',
                          value: widget.vehicle.callNumber,
                        ),
                        if (widget.vehicle.whatsappNumber.isNotEmpty)
                          _InfoRow(
                            icon: Icons.message_outlined,
                            label: 'WhatsApp Number',
                            value: widget.vehicle.whatsappNumber,
                            valueColor: AppColors.green,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR STICKER (matches image design) ──────────────────────────────────────
class _QrSticker extends StatelessWidget {
  final VehicleModel vehicle;
  final String qrData;

  const _QrSticker({required this.vehicle, required this.qrData});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6B5CE7), width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            // Diagonal "SECURE PARK" watermark
            Positioned.fill(
              child: CustomPaint(painter: _WatermarkPainter()),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 30, vertical: 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car,
                      size: 42, color: Color(0xFF333333)),
                  const SizedBox(height: 12),
                  const Text(
                    'Vehicle Contact\nSystem',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Vehicle: ${vehicle.vehicleNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan to contact vehicle owner',
                    style: TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.black87, width: 2.5),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'In case of emergency or blocking, please\nscan this QR.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WATERMARK PAINTER ───────────────────────────────────────────────────────
class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SECURE PARK',
        style: TextStyle(
          color: Color(0x1F000000),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    const angle = -0.48;
    const rowSpacing = 72.0;
    const colSpacing = 155.0;
    for (double y = -size.height; y < size.height * 2; y += rowSpacing) {
      for (double x = -size.width; x < size.width * 2; x += colSpacing) {
        canvas.save();
        canvas.translate(x + tp.width / 2, y + tp.height / 2);
        canvas.rotate(angle);
        canvas.translate(-tp.width / 2, -tp.height / 2);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── INFO ROW ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
