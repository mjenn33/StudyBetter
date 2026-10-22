/// How well the user remembered a flashcard, chosen after flipping it.
///
/// The SM-2 scheduler maps these to quality 0 / 3 / 4 / 5 (docs/PLAN.md §7).
enum Grade { again, hard, good, easy }
