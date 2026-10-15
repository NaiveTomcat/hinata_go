import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinata_go/models/card/card.dart';
import 'package:hinata_go/models/card/ndef.dart';
import 'package:hinata_go/models/card/iso14443a.dart';
import 'package:hinata_go/models/card/felica.dart';
import 'package:hinata_go/models/card/saved_card.dart';
import 'package:ndef/ndef.dart' as ndef;

void main() {
  test('rejects invalid or recursive imported tag metadata', () {
    final json = NdefCard.fromRecords([]).toJson();
    expect(
      () => NdefCard.fromJson({...json, 'capacity': -1}),
      throwsFormatException,
    );
    expect(
      () => NdefCard.fromJson({...json, 'physicalCard': json}),
      throwsFormatException,
    );
  });

  test('physical tag metadata survives storage without enabling game use', () {
    final message = NdefCard.fromRecords([
      ndef.TextRecord(text: 'tag', language: 'en'),
    ]).message;
    for (final tag in [
      Iso14443(Uint8List.fromList([1, 2, 3, 4]), 8, 4),
      Felica(Uint8List(8), Uint8List(8), Uint16List.fromList([0x12fc])),
    ]) {
      final card = NdefCard(message, physicalCard: tag, capacity: 720);
      final loaded =
          ICCard.fromJson(
                jsonDecode(jsonEncode(card.toJson())) as Map<String, dynamic>,
              )
              as NdefCard;
      expect(loaded.physicalCard!.toJson(), tag.toJson());
      expect(loaded.capacity, 720);
      expect(loaded.gamePayload, isNull);
      expect(loaded.tags, contains(CardTag.ndef));
      expect(loaded.name, tag.name);
      expect(card.isSameCard(NdefCard(message)), isFalse);
    }
  });
  test(
    'textual external data is readable while binary payloads remain lossless',
    () {
      for (final tnf in [
        ndef.TypeNameFormat.media,
        ndef.TypeNameFormat.nfcExternal,
      ]) {
        ndef.NDEFRecord record(List<int> payload) => ndef.NDEFRecord(
          tnf: tnf,
          type: Uint8List.fromList(
            utf8.encode(
              tnf == ndef.TypeNameFormat.media
                  ? 'application/octet-stream'
                  : 'neri.moe:hinata',
            ),
          ),
          payload: Uint8List.fromList(payload),
        );
        expect(ndefRecordValue(record(utf8.encode('hello'))), 'hello');
        expect(ndefRecordValue(record([0, 1, 2])), '00 01 02');
        expect(ndefRecordValue(record([0xff, 0x80])), 'FF 80');
      }
    },
  );

  test(
    'persists multiple records, binary payloads and identifiers losslessly',
    () {
      final card = NdefCard.fromRecords([
        ndef.TextRecord(text: '你好', language: 'zh'),
        ndef.UriRecord.fromString('https://example.org/a'),
        ndef.NDEFRecord(
          tnf: ndef.TypeNameFormat.nfcExternal,
          type: Uint8List.fromList(utf8.encode('example.org:binary')),
          id: Uint8List.fromList([0, 255]),
          payload: Uint8List.fromList([0, 255, 128]),
        ),
      ]);
      final saved = SavedCard(
        id: '1',
        name: 'NDEF',
        card: card,
        folderId: 'favorites_folder',
      );
      final loaded = SavedCard.fromJson(
        jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
      );
      expect(loaded.card, isA<NdefCard>());
      expect((loaded.card as NdefCard).message, card.message);
      expect(loaded.card.gamePayload, isNull);
      expect(loaded.card.tags, contains(CardTag.ndef));
      expect(ndefRecordValue(card.records.first), '你好');
      expect(card.records.last.payload, [0, 255, 128]);
      expect(card.records.last.id, [0, 255]);
    },
  );

  test('new datasets deduplicate by content instead of their empty UID', () {
    final a = NdefCard.fromRecords([
      ndef.TextRecord(text: 'a', language: 'en'),
    ]);
    final b = NdefCard.fromRecords([
      ndef.TextRecord(text: 'b', language: 'en'),
    ]);
    expect(a.isSameCard(b), isFalse);
    expect(a.isSameCard(ICCard.fromJson(a.toJson())), isTrue);
  });

  test(
    'recognizes exact Prism origins and smart posters, never lookalike hosts',
    () {
      for (final host in ['link.neri.moe', 'link-beta.neri.moe']) {
        final uri = ndef.UriRecord.fromString('https://$host/t/shop/machine');
        expect(NdefCard.fromRecords([uri]).prismUrl?.host, host);
        final poster = ndef.NDEFRecord(
          tnf: ndef.TypeNameFormat.nfcWellKnown,
          type: Uint8List.fromList([0x53, 0x70]),
          payload: ndef.encodeNdefMessage([uri]),
        );
        expect(NdefCard.fromRecords([poster]).prismUrl?.host, host);
      }
      for (final url in [
        'http://link.neri.moe/t/a/b',
        'https://link.neri.moe.evil.test/t/a/b',
        'https://link.neri.moe@evil.test/t/a/b',
        'https://evil@link.neri.moe/t/a/b',
        'https://link.neri.moe:444/t/a/b',
      ]) {
        expect(
          NdefCard.fromRecords([ndef.UriRecord.fromString(url)]).prismUrl,
          isNull,
        );
      }
    },
  );

  test('malformed smart poster does not prevent storing opaque payloads', () {
    final card = NdefCard.fromRecords([
      ndef.NDEFRecord(
        tnf: ndef.TypeNameFormat.nfcWellKnown,
        type: Uint8List.fromList([0x53, 0x70]),
        payload: Uint8List.fromList([255]),
      ),
    ]);
    expect(card.prismUrl, isNull);
    expect(ndefRecordValue(card.records.single), 'FF');
    expect(card.records.single.payload, [255]);
  });

  test(
    'rejects malformed lengths, position flags, TNF and unterminated chunks',
    () {
      for (final bytes in <List<int>>[
        [0xd1],
        [0xd1, 1, 4, 0x55, 0],
        [0x51, 1, 1, 0x55, 0],
        [0x91, 1, 1, 0x55, 0],
        [0xd7, 0, 0],
        [0xd5, 1, 0, 0x55],
        [0xd6, 0, 0],
        [0xf1, 1, 1, 0x55, 0],
        [0xb1, 1, 1, 0x55, 0],
        [0xd0, 0, 1, 0],
        [0xd1, 1, 1, 0x55, 0, 0],
        [0xc1, 1, 0xff, 0xff, 0xff, 0xff, 0x55],
      ]) {
        expect(
          () => decodeNdef(Uint8List.fromList(bytes)),
          throwsFormatException,
          reason: '$bytes',
        );
      }
    },
  );

  test('reassembles chunked records while keeping original message bytes', () {
    final bytes = Uint8List.fromList([
      0xb1,
      1,
      2,
      0x55,
      4,
      0x61,
      0x56,
      0,
      2,
      0x62,
      0x63,
    ]);
    final card = NdefCard(bytes);
    expect(card.records, hasLength(1));
    expect(ndefRecordValue(card.records.single), 'https://abc');
    expect(card.message, bytes);
  });

  test('supports long NDEF records and valid zero-length messages', () {
    final card = NdefCard.fromRecords([
      ndef.TextRecord(text: '文' * 300, language: 'zh'),
    ]);
    expect(ndefRecordValue(card.records.single), '文' * 300);
    expect(decodeNdef(Uint8List(0)), isEmpty);
  });
}
