import 'iso14443a.dart';

class Nesica extends Iso14443 {
  Nesica(super.id, super.sak, super.atqa, {required this.serial, super.tags});

  final String serial;

  String get serialFormatted {
    if (serial.isEmpty) return serial;
    final groups = <String>[];
    for (int i = 0; i < serial.length; i += 4) {
      final end = i + 4 < serial.length ? i + 4 : serial.length;
      groups.add(serial.substring(i, end));
    }
    return groups.join(' ');
  }

  @override
  String get name => 'NESiCA';

  @override
  String? get type => 'nesica';

  @override
  String get showedValue => serialFormatted;

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'serial': serial};
  }

  factory Nesica.fromJson(Map<String, dynamic> json) {
    final iso = Iso14443.fromJson(json);
    return Nesica(
      iso.id,
      iso.sak,
      iso.atqa,
      serial: json['serial'] as String? ?? '',
      tags: iso.tags,
    );
  }
}
