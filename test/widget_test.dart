import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_q/main.dart';
import 'package:view_q/library.dart';

class FakeLibrary extends Library {
  @override
  Future<LibraryPageResult> browse(
    String value, {
    int offset = 0,
    String category = '',
    DateTime? from,
    DateTime? until,
    List<String>? ids,
  }) async => LibraryPageResult(await list(value), false, items.length);
  @override
  Future<Map<String, int>> indexStatus() async => {};
  @override
  Future<Set<String>> favorites([String? toggleId]) async => {};
  @override
  Future<List<String>> searchHistory([String? openedId]) async => [];
  @override
  Future<bool> themeMode([bool? dark]) async => dark ?? true;
  @override
  Future<List<Screenshot>> previews(String value) => list(value);
  List<Screenshot> items = [];
  String query = '';
  Completer<bool>? pendingPick;
  bool fail = false;
  int deletes = 0;
  @override
  Future<void> resume() async {}
  @override
  Future<List<Screenshot>> list(String value) async {
    query = value;
    if (fail) throw Exception('disk');
    return items;
  }

  @override
  Future<bool> pick() => pendingPick!.future;
  @override
  Future<void> delete(String id) async {
    deletes++;
    items.removeWhere((item) => item.id == id);
  }
}

void main() {
  testWidgets('leaving an edited transcript asks before discarding it', (
    tester,
  ) async {
    final item = Screenshot(
      id: 'draft',
      path: 'missing-test-image.png',
      created: DateTime(2026),
      status: 'done',
      text: 'Original words',
      snippet: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(item: item, library: FakeLibrary()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Edit text'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Corrected booking code');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Corrected booking code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('detail supports large text and confirms before deleting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final item = Screenshot(
      id: 'one',
      path: 'missing-test-image.png',
      created: DateTime(2026),
      status: 'failed',
      text: '',
      snippet: '',
    );
    final library = FakeLibrary()..items = [item];
    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(item: item, library: library),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Delete'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 8 &&
          find
              .widgetWithText(TextButton, 'Delete')
              .hitTestable()
              .evaluate()
              .isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete screenshot?'), findsOneWidget);
    expect(library.deletes, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(library.deletes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home has labeled, accessible touch targets and contrast', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ViewQApp(library: FakeLibrary()));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });
  testWidgets('empty library explains sharing; search remains available', (
    tester,
  ) async {
    final library = FakeLibrary();
    await tester.pumpWidget(ViewQApp(library: library));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'To save a screenshot, tap Share on the image and choose View Q.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'train, ticket');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(library.query, 'train, ticket');
    expect(find.text('No matching screenshots'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('save confirmation waits for durable native success', (
    tester,
  ) async {
    final library = FakeLibrary()..pendingPick = Completer<bool>();
    await tester.pumpWidget(ViewQApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save screenshot'));
    await tester.pump();
    expect(find.text('Screenshot saved'), findsNothing);
    library.pendingPick!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('cancelled picker does not report success', (tester) async {
    final library = FakeLibrary()..pendingPick = Completer<bool>();
    await tester.pumpWidget(ViewQApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save screenshot'));
    library.pendingPick!.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot saved'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('large text on narrow phone is scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(ViewQApp(library: FakeLibrary()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('storage failure has a retry action and recovers', (
    tester,
  ) async {
    final library = FakeLibrary()..fail = true;
    await tester.pumpWidget(ViewQApp(library: library));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    library.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
