import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/security_service.dart';
import 'security_page.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, required this.securityService});

  final SecurityService securityService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('security_title'))),
      body: SecurityPage(securityService: securityService),
    );
  }
}
