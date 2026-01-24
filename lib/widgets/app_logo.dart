import 'package:flutter/material.dart';
import 'package:hostelapp/utils/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          Icons.hexagon,
          color: AppTheme.primaryBlue,
          size: size * 0.6,
        ),
      ),
    );
  }
}
