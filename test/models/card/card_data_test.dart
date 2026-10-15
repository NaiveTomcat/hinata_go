import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinata_go/models/card/aime.dart';
import 'package:hinata_go/models/card/banapass.dart';
import 'package:hinata_go/models/card/card.dart';
import 'package:hinata_go/models/card/iso14443a.dart';
import 'package:hinata_go/models/card/ndef.dart';
import 'package:hinata_go/models/card/saved_card.dart';
import 'package:hinata_go/models/scan_log.dart';

void main() {
  final accessCode = ICCard.hexToBytes('01234567890123456789');
  final tag = Iso14443(
    ICCard.hexToBytes('01020304'),
    8,
    4,
    sakKnown: false,
    atqaKnown: false,
  );
  final legacyAime = <String, dynamic>{
    'type': 'aime',
    'id': '00000000',
    'sak': 8,
    'atqa': 4,
    'accessCode': '01234567890123456789',
    'tags': ['aime', 'mifare_classic'],
  };
  Map<String, dynamic> saved(Map<String, dynamic> card, {String? source}) => {
    'id': 'entry-id',
    'name': 'My card',
    'folderId': 'default',
    'card': card,
    'source': ?source,
  };

  test('portable data stores no synthetic chip fields', () {
    for (final card in <CardData>[
      Aime(accessCode),
      Banapass.fromAccessCode(
        accessCode: '30746056644448171490',
        dualKey: true,
      ),
      NdefCard.fromRecords([]),
    ]) {
      expect(card, isNot(isA<Iso14443>()));
      expect(card.hasPhysicalCard, isFalse);
      expect(card.id, isEmpty);
      final json = card.toJson();
      expect(json, containsPair('physicalCard', null));
      for (final key in ['id', 'sak', 'atqa']) {
        expect(json.containsKey(key), isFalse);
      }
      final restored =
          ICCard.fromJson(jsonDecode(jsonEncode(json))) as CardData;
      expect(restored.hasPhysicalCard, isFalse);
      expect(restored.toJson(), json);
    }
  });

  test('reader conversions keep the actual tag and unavailable parameters', () {
    for (final card in <CardData>[
      tag.toAime(accessCode),
      tag.toBanapass(Uint8List(16), null),
      NdefCard(Uint8List(0), physicalCard: tag, capacity: 720),
    ]) {
      expect(card.physicalCard, same(tag));
      expect(card.idString, '01020304');
      final loaded = ICCard.fromJson(card.toJson()) as CardData;
      expect(loaded.physicalCard!.toJson(), tag.toJson());
      expect(loaded.toJson().containsKey('id'), isFalse);
    }
  });

  test('only known manual and QR placeholders are removed from old cards', () {
    for (final source in ['Direct', 'QR']) {
      final loaded = SavedCard.fromJson(saved(legacyAime, source: source));
      expect((loaded.card as CardData).hasPhysicalCard, isFalse);
      expect(loaded.card.tags, isNot(contains(CardTag.mifareClassic)));
      expect(loaded.card.gamePayload, '01234567890123456789');
      expect(loaded.id, 'entry-id');
      expect(loaded.name, 'My card');
      expect(
        SavedCard.fromJson(loaded.toJson()).card.toJson(),
        loaded.card.toJson(),
      );
    }
    for (final source in [null, 'NFC', 'HINATA']) {
      final loaded = SavedCard.fromJson(saved(legacyAime, source: source));
      expect((loaded.card as CardData).hasPhysicalCard, isTrue);
      expect(loaded.card.idString, '00000000');
    }
    final real = SavedCard.fromJson(
      saved({...legacyAime, 'id': '01020304'}, source: 'Direct'),
    );
    expect((real.card as CardData).hasPhysicalCard, isTrue);
  });

  test(
    'new explicit physical metadata takes precedence over old top-level IDs',
    () {
      final manual =
          ICCard.fromJson({...legacyAime, 'physicalCard': null}, source: 'NFC')
              as CardData;
      expect(manual.hasPhysicalCard, isFalse);
      final real =
          ICCard.fromJson({
                ...legacyAime,
                'physicalCard': Iso14443(Uint8List(4), 8, 4).toJson(),
              }, source: 'Direct')
              as CardData;
      expect(real.hasPhysicalCard, isTrue);
      expect(real.idString, '00000000');
    },
  );

  test('legacy physical and portable Banapass records both migrate', () {
    final legacy = <String, dynamic>{
      'type': 'mifare',
      'id': '',
      'sak': 8,
      'atqa': 0x0400,
      'accessCode': '30746056644448171490',
      'dualKey': true,
    };
    final manual = ICCard.fromJson(legacy) as Banapass;
    expect(manual.hasPhysicalCard, isFalse);
    expect(manual.accessCodeString, '30746056644448171490');
    final physical = ICCard.fromJson({...legacy, 'id': '01020304'}) as Banapass;
    expect(physical.physicalCard, isA<Iso14443>());
    expect((physical.physicalCard as Iso14443).atqa, 0x0400);
  });

  test('legacy NDEF messages with UID become physical snapshots', () {
    final legacy = {
      'type': 'ndef',
      'id': '01020304',
      'message': '',
      'capacity': 144,
    };
    final card = ICCard.fromJson(legacy) as NdefCard;
    expect(card.hasPhysicalCard, isTrue);
    expect(card.idString, '01020304');
    expect(card.capacity, 144);
    expect(NdefCard.fromJson(card.toJson()).physicalCard!.idString, '01020304');
  });

  test('scan history migrates QR placeholders and flat access codes', () {
    final json = <String, dynamic>{
      'id': 'log',
      'source': 'QR',
      'timestamp': '2026-10-14T00:00:00Z',
      'card': legacyAime,
    };
    expect((ScanLog.fromJson(json).card as CardData).hasPhysicalCard, isFalse);
    for (final type in ['aime', 'banapass']) {
      final card =
          ICCard.fromTypeAndValue(type, '30746056644448171490') as CardData;
      expect(card.hasPhysicalCard, isFalse);
      expect(card.id, isEmpty);
    }
  });

  test('business data cannot be nested as physical tag metadata', () {
    final data = Aime(accessCode);
    expect(
      () => NdefCard(Uint8List(0), physicalCard: data),
      throwsFormatException,
    );
    for (final type in ['aime', 'banapass', 'ndef']) {
      final json = <String, dynamic>{
        'type': type,
        'physicalCard': data.toJson(),
        'message': '',
        'accessCode': '',
      };
      expect(() => ICCard.fromJson(json), throwsFormatException);
    }
  });

  test('portable Banapass identity uses data, never the empty chip ID', () {
    final first = Banapass(Uint8List.fromList(List.filled(16, 1)), null);
    final sameData = Banapass(
      Uint8List.fromList(List.filled(16, 1)),
      null,
      physicalCard: tag,
    );
    final different = Banapass(Uint8List.fromList(List.filled(16, 2)), null);
    expect(first.isSameCard(sameData), isTrue);
    expect(first.isSameCard(different), isFalse);
    expect(ICCard(Uint8List(0)).isSameCard(ICCard(Uint8List(0))), isFalse);
    expect(Aime(accessCode).isSameCard(tag.toAime(accessCode)), isTrue);
  });
}
