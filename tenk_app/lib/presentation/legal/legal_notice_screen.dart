import 'package:flutter/material.dart';

import '../../config/legal_config.dart';
import '../../design/tokens.dart';
import 'consent_section.dart';

/// '내 정보' → '법적 고지' 하위 화면. 이용약관·개인정보처리방침을 외부 브라우저로 연다(상시 접근).
class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('법적 고지')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('이용약관'),
              trailing: const Icon(Icons.open_in_new,
                  size: 18, color: AppColors.inkMuted),
              onTap: () => openLegalDoc(context, termsUrl),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('개인정보처리방침'),
              trailing: const Icon(Icons.open_in_new,
                  size: 18, color: AppColors.inkMuted),
              onTap: () => openLegalDoc(context, privacyPolicyUrl),
            ),
            const Divider(height: 1),
            // 오픈소스 라이선스 고지 — 국내 관례대로 '법적 고지'(약관 묶음) 안에 둔다.
            // Flutter 기본 라이선스 화면(showLicensePage)이 의존성 라이선스를 자동 수집·표시.
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('오픈소스 라이선스'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'TenK',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
