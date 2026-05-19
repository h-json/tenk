import 'package:flutter/foundation.dart';

@immutable
class AmountMediaFile {
  const AmountMediaFile({
    required this.fileId,
    required this.filePath,
    required this.originalName,
  });

  final int fileId;
  final String filePath;
  final String originalName;

  factory AmountMediaFile.fromJson(Map<String, dynamic> json) {
    return AmountMediaFile(
      fileId: (json['fileId'] as num).toInt(),
      filePath: json['filePath'] as String,
      originalName: json['originalName'] as String,
    );
  }
}

@immutable
class Amount {
  const Amount({
    required this.id,
    required this.challengeId,
    required this.category,
    required this.content,
    required this.amount,
    required this.noSpend,
    required this.spentDt,
    required this.mediaFiles,
  });

  final int id;
  final int challengeId;
  final String? category;
  final String? content;
  final int amount;
  final bool noSpend;

  /// 사용자가 선택한 "지출 발생 일시" (날짜 부분이 챌린지 기간 안에 있어야 함).
  /// 백엔드는 `LocalDateTime` (타임존 없음)으로 보낸다.
  final DateTime spentDt;
  final List<AmountMediaFile> mediaFiles;

  factory Amount.fromJson(Map<String, dynamic> json) {
    final media = (json['mediaFiles'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AmountMediaFile.fromJson)
        .toList(growable: false);
    return Amount(
      id: (json['amountId'] as num).toInt(),
      challengeId: (json['challengeId'] as num).toInt(),
      category: json['category'] as String?,
      content: json['content'] as String?,
      amount: (json['amount'] as num).toInt(),
      noSpend: json['noSpend'] as bool,
      spentDt: DateTime.parse(json['spentDt'] as String),
      mediaFiles: media,
    );
  }
}
