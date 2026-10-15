import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndef/ndef.dart' as ndef;

import '../l10n/l10n.dart';
import '../models/card/ndef.dart';

String ndefRecordLabel(ndef.NDEFRecord record) {
  if (ndefRecordUri(record) != null) return l10n.ndefLink;
  if (record.tnf == ndef.TypeNameFormat.nfcWellKnown &&
      listEquals(record.type, [0x54])) {
    return l10n.ndefText;
  }
  final type = utf8.decode(record.type ?? [], allowMalformed: true);
  if (record.tnf == ndef.TypeNameFormat.media) return 'MIME · $type';
  if (record.tnf == ndef.TypeNameFormat.nfcExternal) {
    return '${l10n.ndefExternal} · $type';
  }
  return l10n.ndefRaw;
}

IconData ndefRecordIcon(ndef.NDEFRecord record) {
  if (ndefRecordUri(record) != null) return Icons.link;
  if (record.tnf == ndef.TypeNameFormat.media) {
    return Icons.description_outlined;
  }
  if (record.tnf == ndef.TypeNameFormat.nfcExternal) {
    return Icons.extension_outlined;
  }
  if (record.tnf == ndef.TypeNameFormat.nfcWellKnown &&
      listEquals(record.type, [0x54])) {
    return Icons.notes;
  }
  return Icons.data_object;
}

String ndefTnfLabel(ndef.TypeNameFormat tnf) => switch (tnf) {
  ndef.TypeNameFormat.empty => l10n.ndefTnfEmpty,
  ndef.TypeNameFormat.nfcWellKnown => l10n.ndefTnfWellKnown,
  ndef.TypeNameFormat.media => 'MIME',
  ndef.TypeNameFormat.absoluteURI => l10n.ndefLink,
  ndef.TypeNameFormat.nfcExternal => l10n.ndefExternal,
  ndef.TypeNameFormat.unknown => l10n.ndefTnfUnknown,
  ndef.TypeNameFormat.unchanged => l10n.ndefTnfUnchanged,
};
