import 'package:hinata_go/core/engine/mifare_write_payload.dart';
import 'package:hinata_go/models/card/iso14443a.dart';
import 'dart:typed_data';

import 'package:cardcipher/bana.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinata_go/models/card/banapass.dart';
import 'package:hinata_go/models/card/card.dart';

void main() {
  final card = Banapass(
    Uint8List(16),
    null,
    physicalCard: Iso14443(Uint8List.fromList([1, 2, 3, 4]), 8, 0x0400),
  );

  test('serializes with the Banapass domain type', () {
    expect(card.toJson()['type'], 'banapass');
  });

  test('still reads legacy Mifare payloads', () {
    final decoded = ICCard.fromJson({...card.toJson(), 'type': 'mifare'});

    expect(decoded, isA<Banapass>());
  });

  test('reconstructs Access Code from a physical dual-key block', () {
    final physicalBlock2 = ICCard.hexToBytes(
      '00000000000030746056644448171490',
    );
    final reconstructed = Banapass.fromBlocks(
      block1: Uint8List(16),
      block2: physicalBlock2,
      physicalCard: card.physicalCard,
    );

    expect(reconstructed.dualKey, isTrue);
    expect(reconstructed.accessCodeString, '30746056644448171490');
    expect(reconstructed.toJson()['accessCode'], '30746056644448171490');
  });

  test('keeps canonical construction and single-key intent', () {
    final reconstructed = Banapass.fromAccessCode(
      accessCode: '30746056644448171490',
      serial: 205050,
      keyNumber: 6,
      unknown04: 0,
      unknown06: 3,
      appData: 0,
      dualKey: false,
      physicalCard: card.physicalCard,
    );

    expect(reconstructed.serial, 205050);
    expect(reconstructed.keyNumber, 6);
    expect(reconstructed.dualKey, isFalse);
    expect(reconstructed.effectiveBlock2, isNull);
    expect(reconstructed.toJson(), containsPair('serial', 205050));
    expect(reconstructed.toJson(), containsPair('keyNumber', 6));
    expect(reconstructed.toJson(), containsPair('dualKey', false));
  });

  test('treats a flat Access Code as an access-code-only card', () {
    final reconstructed =
        ICCard.fromTypeAndValue('banapass', '30746056644448171490') as Banapass;

    expect(reconstructed.dualKey, isTrue);
    expect(reconstructed.effectiveBlock2, hasLength(16));
  });
  test(
    'private cipher reconstructs writable blocks from only Access Code',
    () {
      final card = Banapass.fromAccessCode(
        accessCode: '30746056644448171490',
        dualKey: true,
      );
      expect(card.physicalCard, isNull);
      expect(card.serial, 205050);
      expect(card.keyNumber, 6);
      expect(card.unknown04, 0);
      expect(card.unknown06, 3);
      expect(card.block1Hex, '00024e424749433665d8206336cdb5c2');
      expect(card.block2Hex, '00000000000030746056644448171490');
      expect(MifareCardWritePayload.canBuild(card), isTrue);
      for (final mode in CardWriteMode.values) {
        final payload = MifareCardWritePayload.fromCard(card, mode);
        expect(payload.dataBlocks[1], card.effectiveBlock1);
        expect(payload.dataBlocks[2], card.effectiveBlock2);
      }
      expect(Banapass.fromJson(card.toJson()).toJson(), card.toJson());
      expect(
        card.toRemoteJson(includeCanonicalFields: false)['block1'],
        card.block1Hex,
      );
      final invalid = Banapass.fromAccessCode(
        accessCode: '30746056644448171491',
        dualKey: true,
      );
      expect(MifareCardWritePayload.canBuild(invalid), isFalse);
    },
    skip: !BanapassCipher.isAvailable()
        ? 'The public cipher does not implement Banapass reconstruction'
        : false,
  );
}
