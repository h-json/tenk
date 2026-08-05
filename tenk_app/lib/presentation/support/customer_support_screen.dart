import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../inquiry/inquiry_screen.dart';

/// 메뉴 → '고객센터'. 자체 콘텐츠 없이 문의 창구로 분기하는 허브다.
///
/// **지금은 '문의하기' 하나뿐인데도 허브로 둔다** — FAQ·공지사항이 들어올 자리라서다.
/// 그 둘이 생기기 전까지 이 화면은 한 줄짜리이고, 그건 의도된 상태다.
///
/// ⚠️ **'의견 보내기'를 여기로 다시 넣지 말 것** (2026-08-06 결정). 익명으로 가볍게 남기는
/// 창구라 고객센터 안에 있으면 "문의할 일이 있어야 여는 곳" 으로 읽혀 문턱이 올라간다.
/// 그쪽은 메뉴 최상위에 둔다.
class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객센터')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('문의하기'),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const InquiryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
