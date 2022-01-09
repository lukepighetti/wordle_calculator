import 'dart:convert';
import 'dart:io';

import 'dart:math';

const deniedLetters = 'aisutbnhdfc';
const knownLetters = 'r';
const wrongPositionKnownLetters = <int, List<String>>{
  1: ['r'],
  2: ['r'],
  3: [],
  4: [],
  5: [],
};
const positionedKnownLetters = {
  1: null,
  2: 'o',
  3: 'r',
  4: null,
  5: 'e',
};

void main(List<String> arguments) async {
  /// 1. load dictionary
  final dictionary = await File('assets/dictionary.txt').readAsLines();
  assert(dictionary.first == 'aa');
  assert(dictionary.last == 'zyzzyvas');
  print('Loaded ${dictionary.length} words');

  /// 2. remove words that aren't five letters
  dictionary.removeWhere((it) => it.length != 5);
  print('Reduced to ${dictionary.length} five letter words');

  /// 3. Load letter frequency
  final frequency = await File('assets/letter_frequency.json')
      .readAsString()
      .then((it) => Map<String, double>.from(jsonDecode(it)));
  assert(frequency['A'] == 0.078);

  /// 4. define denied letters, filter
  final denied = deniedLetters.toList();
  dictionary.removeWhere((it) => it.toList().containsAny(denied));
  print('Reduced to ${dictionary.length} words by denying $denied');

  /// 5. define known letters, filter
  final known = knownLetters.toList();

  if (known.isNotEmpty) {
    dictionary.retainWhere((it) => it.toList().containsAll(known));
    print('Reduced to ${dictionary.length} words by requiring $known');
  }

  /// 6. define wrong position known letters, filter
  final wrongPositionKnown = wrongPositionKnownLetters.withoutEmptyValues;

  if (wrongPositionKnown.values.flattened.isNotEmpty) {
    for (final entry in wrongPositionKnown.entries) {
      final position = entry.key;
      final letters = entry.value;

      for (final letter in letters) {
        final index = position - 1;
        dictionary.retainWhere((it) => !it.containsAtIndex(letter, index));
      }
    }
    print(
        'Reduced to ${dictionary.length} words by denying wrongly positioned $wrongPositionKnown');
  }

  /// 7. define positioned known letters, filter
  final positioned = positionedKnownLetters.withoutNullValues;

  if (positioned.isNotEmpty) {
    dictionary.retainWhere((word) {
      final positions = positioned.entries;

      return positions.every((position) {
        final index = position.key - 1;
        final letter = position.value;

        return word.containsAtIndex(letter, index);
      });
    });

    print(
        'Reduced to ${dictionary.length} words by requiring positioned $positioned');
  }

  /// 8. Score all words
  assert(scoreWord('aabc', {'a': 0.1, 'b': 0.2, 'c': 0.3}).isAlmost(0.6));
  final scoredWords = scoreWords(dictionary, frequency);
  final sortedScoredWords = scoredWords.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final topFiveWords = sortedScoredWords.safeSublist(0, 5);
  assert(topFiveWords.length <= 5);

  print(topFiveWords.toPrettyString());
}

Map<String, double> scoreWords(
    List<String> words, Map<String, double> frequency) {
  final scores = <String, double>{};

  for (final word in words) {
    scores[word] = scoreWord(word, frequency);
  }

  return scores;
}

double scoreWord(String word, Map<String, double> frequency) {
  var score = 0.0;

  // if a letter appears in the word, add it's freqency to the score
  for (final entry in frequency.entries) {
    final letter = entry.key;
    final letterScore = entry.value;

    if (word.insensitiveContains(letter)) {
      score += letterScore;
    }
  }

  return score;
}

extension on String {
  List<String> toList() => split('');

  bool insensitiveContains(String needle) =>
      toLowerCase().contains(needle.toLowerCase());

  bool containsAtIndex(String letter, int index) => toList()[index] == letter;
}

extension ListExtensions<T> on List<T> {
  bool containsAny(List<T> needles) => needles.any((it) => contains(it));
  bool containsAll(List<T> needles) => needles.every((it) => contains(it));

  List<T> safeSublist(int start, int end) {
    return sublist(start, min(length, end));
  }
}

extension on num {
  bool isAlmost(num value, {double error = 0.00001}) {
    return value >= value - error && value <= value + error;
  }
}

extension on Iterable<MapEntry<String, double>> {
  String toPrettyString() {
    return Map.fromEntries(this).toString();
  }
}

extension MapExtensions<K, V> on Map<K, V?> {
  Map<K, V> get withoutNullValues =>
      Map<K, V>.from(<K, V?>{...this}..removeWhere((k, v) => v == null));
}

extension IterableIterableX<T> on Iterable<Iterable<T>> {
  List<T> get flattened => fold([], (a, b) => [...a, ...b]);
}

extension MapIterableX<K, V> on Map<K, Iterable<V>> {
  Map<K, List<V>> get withoutEmptyValues =>
      Map.from(this)..removeWhere((k, v) => v.isEmpty);
}
