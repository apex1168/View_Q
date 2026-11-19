import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:view_q/home_screen.dart';
import 'package:view_q/library.dart';

class KeyboardLibrary extends Library {
  @override
  Future<LibraryPageResult> browse(
    String query, {
    int offset = 0,
    String category = '',
    DateTime? from,
    DateTime? until,
    List<String>? ids,
  }) async => const LibraryPageResult([], false, 0);
  @override
  Future<void> resume() async {}
  @override
  Future<List<Screenshot>> previews(String query) async => [];
  @override
  Future<Map<String, int>> indexStatus() async => {};
  @override
  Future<Set<String>> favorites([String? toggleId]) async => {};
  @override
  Future<List<String>> searchHistory([String? openedId]) async => [];
}

void main() {
  testWidgets('search retains editing focus when keyboard hides the heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(library: KeyboardLibrary())),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    final before = tester.state<EditableTextState>(find.byType(EditableText));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final after = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(before, after), isTrue);
    expect(after.widget.focusNode.hasFocus, isTrue);
    await tester.enterText(field, 'ticket');
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('ticket'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
