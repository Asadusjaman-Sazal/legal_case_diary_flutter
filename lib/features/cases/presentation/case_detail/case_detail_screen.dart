/// Case detail screen: shows KanBan cards for Parties, Description, Case History.
/// Implemented in Task 10.
library;

import 'package:flutter/material.dart';

class CaseDetailScreen extends StatelessWidget {
  final String caseId;
  const CaseDetailScreen({required this.caseId, super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Case Detail [$caseId] — Task 10')));
}
