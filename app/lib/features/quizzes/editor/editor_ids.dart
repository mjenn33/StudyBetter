/// Short, readable ids for new questions (`q1`, `q2`, …) and options
/// (`a`, `b`, …). They only need to be unique within their quiz or question,
/// and stay stable once created because history refers to them.
library;

/// The first `q<n>` (n ≥ 1) not in [existing].
String nextQuestionId(Iterable<String> existing) {
  final used = existing.toSet();
  var n = 1;
  while (used.contains('q$n')) {
    n++;
  }
  return 'q$n';
}

/// The first unused id in `a`…`z`, then `aa`, `ab`, ….
String nextOptionId(Iterable<String> existing) {
  final used = existing.toSet();
  for (var i = 0; ; i++) {
    final id = _letters(i);
    if (!used.contains(id)) return id;
  }
}

String _letters(int index) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz';
  var n = index;
  var result = '';
  do {
    result = alphabet[n % 26] + result;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return result;
}
