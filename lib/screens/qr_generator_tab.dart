// lib/screens/qr_generator_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/qr_location_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGeneratorTab extends StatefulWidget {
  const QrGeneratorTab({super.key});

  @override
  State<QrGeneratorTab> createState() => _QrGeneratorTabState();
}

class _QrGeneratorTabState extends State<QrGeneratorTab> {
  final CollectionReference _locationCollection =
      FirebaseFirestore.instance.collection('qr_locations');

  /// Shows a dialog to add or edit a location.
  void _showLocationDialog({QrLocation? location}) {
    final nameController = TextEditingController(text: location?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(location == null ? 'เพิ่มพื้นที่ใหม่' : 'แก้ไขชื่อพื้นที่'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'ชื่อพื้นที่ (เช่น ประตูหน้า)'),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกชื่อพื้นที่';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                try {
                  if (location == null) {
                    // Add new location
                    await _locationCollection.add({'name': name});
                  } else {
                    // Update existing location
                    await _locationCollection.doc(location.id).update({'name': name});
                  }
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  // Handle error
                }
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  /// Shows the generated QR code for a specific location.
  void _showQrDialog(QrLocation location) {
    // The data format is important for the scanner to recognize it.
    final qrData = 'HRLOC::${location.id}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('QR Code สำหรับ: ${location.name}'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 250.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _locationCollection.snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีพื้นที่สำหรับสร้าง QR Code'));
          }

          final locations = snapshot.data!.docs
              .map((doc) => QrLocation.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Space for FAB
            itemCount: locations.length,
            itemBuilder: (ctx, index) {
              final loc = locations[index];
              return ListTile(
                leading: const Icon(Icons.qr_code_2_sharp),
                title: Text(loc.name, style: GoogleFonts.anuphan()),
                onTap: () => _showQrDialog(loc),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showLocationDialog(location: loc),
                      tooltip: 'แก้ไขชื่อ',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _locationCollection.doc(loc.id).delete(),
                      tooltip: 'ลบ',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLocationDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
