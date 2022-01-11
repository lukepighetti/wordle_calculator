import 'dart:async';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';

const guesses = ['arise', 'force', 'toner', 'clerk', 'emery', 'query'];

// TODO: handle invalid word error
// TODO: handle wins
// TODO: handle losses
Future<void> main() async {
  /// 1. visit Wordle website
  final browser = await puppeteer.launch();
  final myPage = await browser.newPage();
  await myPage.goto('https://www.powerlanguage.co.uk/wordle/',
      wait: Until.networkIdle);
  await myPage.saveScreenshot();

  // 2. Close modal
  await myPage.tapCloseButton();
  await myPage.pump();
  await myPage.saveScreenshot();

  // 3. guess a few wordles
  for (final guess in guesses) {
    var result = await myPage.guessWordle(guess);
    await myPage.pump();
    await myPage.saveScreenshot();
    print(result.toShortString());
  }

  // Cleanup
  await browser.close();
}

extension on Page {
  static var _screenshots = 0;

  Future<void> saveScreenshot() async {
    _screenshots++;

    final png = await screenshot();
    await File('screenshot-$_screenshots.png').writeAsBytes(png);
  }

  Future<List<TileResult>> guessWordle(String word) async {
    // 1. make sure we can guess a wordle
    var gridState = await getGridState();
    assert(gridState.complete == false);

    // 2. guess wordle
    await typeWordle(word);
    await pump();
    gridState = await getGridState();

    // 3. parse results
    final results = gridState.lastCompleteRow
        .mapIndex((it, i) => TileResult(letter: word.letters[i], state: it));

    return results;
  }

  Future<void> typeWordle(String word) async {
    assert(word.length == 5);
    await keyboard.type(word);
    await keyboard.press(Key.enter);
  }

  Future<void> tapCloseButton() async {
    final element = await evaluateHandle(
        'document.querySelector("body > game-app").shadowRoot'
        '.querySelector("#game > game-modal").shadowRoot'
        '.querySelector("div > div > div > game-icon")');

    await element.asElement!.tap();
  }

  /// [row] is from 1-6, [tile] is from 1-5
  Future<TileState> getTileState(int row, int tile) async {
    assert(row >= 1 && row <= 6);
    assert(tile >= 1 && tile <= 5);

    final attribute = await evaluateHandle(
        'document.querySelector("body > game-app").shadowRoot'
        '.querySelector("#board > game-row:nth-child($row)").shadowRoot'
        '.querySelector("div > game-tile:nth-child($tile)").shadowRoot'
        '.querySelector("div")'
        '.getAttribute("data-state")');

    final state = await attribute.jsonValue as String;
    return TileState.values.firstWhere((it) => it.name == state);
  }

  /// Get the state for an entire row
  Future<List<TileState>> getRowState(int row) async {
    return Future.wait([
      getTileState(row, 1),
      getTileState(row, 2),
      getTileState(row, 3),
      getTileState(row, 4),
      getTileState(row, 5),
    ]);
  }

  Future<List<List<TileState>>> getGridState() async {
    return Future.wait([
      getRowState(1),
      getRowState(2),
      getRowState(3),
      getRowState(4),
      getRowState(5),
      getRowState(6),
    ]);
  }

  Future<void> pump() async {
    await Future.delayed(Duration(seconds: 2));
  }
}

enum TileState {
  /// This tile has not been guessed yet
  empty,

  /// This tile has a guess typed into it, but not yet submitted
  tbd,

  /// This letter is not in the solution
  absent,

  /// This letter is in the solution, but in the wrong position
  present,

  /// This letter is correct: it's in the solution, and in the right position.
  correct,
}

extension _TileStateExtensions on TileState {
  bool get inProgress => this == TileState.tbd;
  bool get complete =>
      this == TileState.absent ||
      this == TileState.present ||
      this == TileState.correct;
}

extension _RowStateExtensions on List<TileState> {
  bool get inProgress => any((it) => it.inProgress);
  bool get complete => every((it) => it.complete);
}

extension _GridStateExtensions on List<List<TileState>> {
  bool get inProgress => any((it) => it.inProgress);
  bool get complete => every((it) => it.complete);
  List<List<TileState>> get completeRows => where((it) => it.complete).toList();
  List<TileState> get lastCompleteRow => completeRows.last;
  int get nextRow => completeRows.length;
}

extension ListExtensions<T> on List<T> {
  List<K> mapIndex<K>(K Function(T, int) fn) {
    final result = <K>[];

    for (var i = 0; i < length; i++) {
      result.add(fn(this[i], i));
    }

    return result;
  }
}

extension StringExtensions on String {
  List<String> get letters => split('');
}

extension IterableMapEntryExtension<K, V> on Iterable<MapEntry<K, V>> {
  Map<K, V> toMap() => Map<K, V>.fromEntries(this);
}

class TileResult {
  TileResult({
    required this.letter,
    required this.state,
  });

  final String letter;

  final TileState state;

  @override
  String toString() => 'TileResult($letter, $state)';

  String toShortString() => '$letter: ${state.name}';
}

extension IterableTileResult on Iterable<TileResult> {
  String toShortString() => map((it) => it.toShortString()).toString();
}
