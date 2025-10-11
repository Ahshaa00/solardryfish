import 'package:flutter/material.dart';
import '../models/user_role.dart';

class PermissionBadge extends StatelessWidget {
  final UserRole role;
  final double fontSize;

  const PermissionBadge({
    super.key,
    required this.role,
    this.fontSize = 11,
  });

  Color get badgeColor {
    switch (role) {
      case UserRole.owner:
        return Colors.amber;
      case UserRole.admin:
        return Colors.blue;
      case UserRole.operator:
        return Colors.green;
      case UserRole.viewer:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        role.displayName.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
