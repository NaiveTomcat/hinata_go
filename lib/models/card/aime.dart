import 'dart:typed_data';

import 'card.dart';
import 'iso14443a.dart';

class Aime extends CardData implements HasAccessCode {
  final Uint8List accessCode;
  Aime(this.accessCode, {super.physicalCard, super.tags});

  @override
  String get accessCodeString =>
      accessCode.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  @override
  String get showedValue => accessCodeString.toUpperCase();

  @override
  String get name => "Aime";

  @override
  String? get logoPath => "assets/cardlogo/aime.svg";

  @override
  String? get type => "aime";

  @override
  String? get gamePayload => accessCodeString;

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'accessCode': accessCodeString};
  }

  factory Aime.fromJson(Map<String, dynamic> json, {String? source}) {
    final physical = CardData.readPhysicalCard(json, source: source);
    return Aime(
      ICCard.hexToBytes(json['accessCode'] as String? ?? ''),
      physicalCard: physical,
      tags:
          (json['tags'] as List<dynamic>?)
              ?.map(CardTag.fromJson)
              .where((tag) => physical != null || tag != CardTag.mifareClassic)
              .toList() ??
          const [],
    );
  }
}

extension ToAime on Iso14443 {
  Aime toAime(Uint8List accessCode, {List<CardTag>? tags}) =>
      Aime(accessCode, physicalCard: this, tags: tags ?? this.tags);
}
