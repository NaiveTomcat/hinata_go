import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hinata_go/core/app_host_mode.dart';
import 'package:hinata_go/l10n/l10n.dart';
import 'package:hinata_go/navigation/router.dart';
import 'package:hinata_go/providers/app_update_provider.dart';
import 'package:hinata_go/providers/app_update_state.dart';
import 'package:hinata_go/providers/navigation_provider.dart';
import 'package:hinata_go/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the app's real router, so the action button is exercised against the actual pages that
/// own one: `/cards` (a shell branch page) and `/instances` (a root-level page).
///
/// The two of them publish to the same native button, and which one wins must not depend on the
/// order their registrars happen to sync in — on a pop, the page going away reports itself last.
const _nativeShellChannel = MethodChannel('dev.hinata.go/native_shell');

class _MockAppUpdateNotifier extends AppUpdateNotifier {
  @override
  AppUpdateState build() => const AppUpdateState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late GoRouter router;
  late List<Map<String, Object?>> actionCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    actionCalls = <Map<String, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeShellChannel, (call) async {
          if (call.method == 'setActionButton') {
            actionCalls.add(Map<String, Object?>.from(call.arguments as Map));
          }
          return null;
        });

    container = ProviderContainer(
      overrides: [
        appHostModeProvider.overrideWithValue(AppHostMode.nativeIOS),
        appUpdateProvider.overrideWith(() => _MockAppUpdateNotifier()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    router = container.read(routerProvider);
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeShellChannel, null);
  });

  testWidgets('the action button follows the real router through /instances', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The scan page has no button of its own.
    expect(container.read(appActionNotifierProvider), isNull);

    router.go('/cards');
    await tester.pumpAndSettle();
    expect(container.read(appActionNotifierProvider)?.id, 'cardsAction');
    expect(
      container
          .read(appActionNotifierProvider)
          ?.menuItems
          ?.map((item) => item.id),
      ['addCard', 'addNdef', 'addFolder'],
    );

    // `/instances` is a root-level route, so it replaces the shell and its own button takes over.
    router.push('/instances');
    await tester.pumpAndSettle();
    expect(container.read(appActionNotifierProvider)?.id, 'addInstance');
    expect((actionCalls.last['config'] as Map?)?['actionId'], 'addInstance');

    // Coming back, the branch page has to get the button back instead of it staying gone.
    router.pop();
    await tester.pumpAndSettle();
    expect(container.read(appActionNotifierProvider)?.id, 'cardsAction');
    expect((actionCalls.last['config'] as Map?)?['actionId'], 'cardsAction');
  });
  testWidgets('native selectTopLevel message changes the real Flutter route', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/scan');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMethodCodec();

    Future<Object?> tapNativeTab(int index) async {
      final response = Completer<ByteData?>();
      messenger.handlePlatformMessage(
        _nativeShellChannel.name,
        codec.encodeMethodCall(
          MethodCall('selectTopLevel', <String, Object?>{'index': index}),
        ),
        response.complete,
      );
      // GoRouter switches its branch after the incoming platform message.
      await tester.pumpAndSettle();
      final envelope = await response.future;
      return codec.decodeEnvelope(envelope!);
    }

    final cardsResponse = await tapNativeTab(1);
    expect((cardsResponse as Map)['accepted'], isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/cards');

    final settingsResponse = await tapNativeTab(2);
    expect((settingsResponse as Map)['accepted'], isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/settings');

    await tapNativeTab(0);
    expect(router.routeInformationProvider.value.uri.path, '/scan');
  });
  testWidgets(
    'NDEF mobile editor covers native tab bar until the whole editor closes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/cards');
      await tester.pumpAndSettle();
      container.read(appActionNotifierProvider.notifier).execute('addNdef');
      await tester.pumpAndSettle();
      expect(container.read(nativeShellCoverageProvider).shellCovered, isTrue);
      await tester.tap(find.text('Add record'));
      await tester.pumpAndSettle();
      expect(container.read(nativeShellCoverageProvider).shellCovered, isTrue);
      await tester.tap(find.byTooltip('Cancel').last);
      await tester.pumpAndSettle();
      expect(container.read(nativeShellCoverageProvider).shellCovered, isTrue);
      await tester.tap(find.byTooltip('Cancel').last);
      await tester.pumpAndSettle();
      expect(container.read(nativeShellCoverageProvider).shellCovered, isFalse);
    },
  );
}
