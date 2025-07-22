import 'package:flutter/material.dart';

class EmployeeAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? gender; // รับเพศ "ชาย" หรือ "หญิง"
  final double radius;

  const EmployeeAvatar({
    super.key,
    required this.imageUrl,
    required this.gender,
    this.radius = 24.0,
  });

  ImageProvider? _getImage() {
    // 1. ถ้ามี URL รูปภาพ, ให้ใช้รูปนั้นก่อน
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return NetworkImage(imageUrl!);
    }
    // 2. ถ้าไม่มี URL, เช็คเพศเพื่อใช้รูปเริ่มต้นจาก assets
    if (gender == 'ชาย') {
      return const AssetImage('assets/images/boy.png');
    }
    if (gender == 'หญิง') {
      return const AssetImage('assets/images/girl.png');
    }
    // 3. ถ้าไม่มีข้อมูลใดๆ เลย (เป็น fallback สุดท้าย)
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImage();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: imageProvider,
      // ถ้าไม่มีรูปภาพใดๆ เลย ให้แสดงไอคอนแทน
      child: imageProvider == null
          ? Icon(
              Icons.person,
              size: radius,
              color: Colors.grey.shade400,
            )
          : null,
    );
  }
}
