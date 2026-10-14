import 'package:flutter/material.dart';
import 'package:ndef/ndef.dart' as ndef;

import '../../../l10n/l10n.dart';
import '../../../models/card/ndef.dart';
import '../../ndef_record_ui.dart';

class NdefRecordsCard extends StatelessWidget {
  final NdefCard card;

  const NdefRecordsCard({required this.card, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final records = card.records;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(Icons.list_alt_rounded, color: colors.primary, size: 22),
        title: Text(
          l10n.ndefRecords,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          const Divider(height: 1),
          for (var i = 0; i < records.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 64),
            _NdefRecordDetails(record: records[i]),
          ],
        ],
      ),
    );
  }
}

class _NdefRecordDetails extends StatelessWidget {
  final ndef.NDEFRecord record;

  const _NdefRecordDetails({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ndefRecordIcon(record),
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ndefRecordLabel(record),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  ndefRecordValue(record),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
