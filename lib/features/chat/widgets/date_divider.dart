import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateDivider extends StatelessWidget {
  final DateTime date;

  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMEd('ko').format(date).replaceAll('(', '').replaceAll(')', ''); // 날짜 포맷 설정

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Text(
        dateFormat,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
