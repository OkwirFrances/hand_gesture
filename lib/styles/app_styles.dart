import 'package:flutter/material.dart';

class AppStyles {
  static const TextStyle jumbotronTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.blueAccent,
  );

  static const TextStyle jumbotronText = TextStyle(
    fontSize: 16,
    color: Colors.black87,
  );

  static final BoxDecoration jumbotronBox = BoxDecoration(
    color: Colors.blue.shade50,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [BoxShadow(blurRadius: 6, color: Colors.grey.shade300)],
  );

  static const Color appBarColor = Colors.blue;
  static const Color footerColor = Colors.white;
}
