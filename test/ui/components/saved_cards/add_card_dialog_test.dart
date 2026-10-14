import 'package:cardcipher/bana.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinata_go/core/engine/mifare_write_payload.dart';
import 'package:hinata_go/l10n/l10n.dart';
import 'package:hinata_go/models/card/aime.dart';
import 'package:hinata_go/models/card/banapass.dart';
import 'package:hinata_go/providers/app_state_provider.dart';
import 'package:hinata_go/providers/storage_provider.dart';
import 'package:hinata_go/ui/components/saved_cards/add_card_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() => container.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            L10nHolder.update(AppLocalizations.of(context));
            return child!;
          },
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AddCardDialog(
                    initialFolderId: 'favorites_folder',
                    onAddFolderRequested: () {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'My card');
  }

  testWidgets('both libraries create portable Aime data', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).last, '01234567890123456789');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    final card = container.read(savedCardsProvider).single.card as Aime;
    expect(card.accessCodeString, '01234567890123456789');
    expect(card.physicalCard, isNull);
  });

  testWidgets(
    'public library blocks 3-prefixed creation; private library creates writable Banapass',
    (tester) async {
      await open(tester);
      await tester.enterText(
        find.byType(TextField).last,
        '30746056644448171491',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text(l10n.banapassAccessCodeCannotCreate), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        '30746056644448171490',
      );
      await tester.pumpAndSettle();
      final save = tester.widget<FilledButton>(find.byType(FilledButton));
      if (BanapassCipher.isAvailable()) {
        expect(save.onPressed, isNotNull);
        expect(find.text(l10n.banapassAccessCodeCannotCreate), findsNothing);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        final card = container.read(savedCardsProvider).single.card as Banapass;
        expect(card.physicalCard, isNull);
        expect(card.accessCodeString, '30746056644448171490');
        expect(MifareCardWritePayload.canBuild(card), isTrue);
      } else {
        expect(save.onPressed, isNull);
        expect(find.text(l10n.banapassAccessCodeCannotCreate), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(container.read(savedCardsProvider), isEmpty);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
