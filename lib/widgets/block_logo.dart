import 'package:flutter/material.dart';
import '../theme.dart';

/// Logo de la app: "NOVADX" en mayusculas con Archivo Black (equivalente libre
/// a Arial Black), en blanco sobre el fondo negro de la app.
class BlockLogo extends StatelessWidget {
  const BlockLogo({super.key, this.fontSize = 52});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'NOVADX',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'ArchivoBlack',
        fontSize: fontSize,
        color: AppColors.textPrimary,
        letterSpacing: 2,
        height: 1.0,
      ),
    );
  }
}
