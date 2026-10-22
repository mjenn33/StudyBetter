import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/library_repository.dart';
import '../quizzes/quiz_readiness.dart';
import 'player_controller.dart';

/// Plays a quiz one question at a time.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(playerProvider(quizId))) {
      AsyncData(:final value) => _Player(quizId: quizId, state: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(switch (error) {
              QuizNotPlayableException(:final problems) =>
                'This quiz has ${problemCount(problems)}. '
                    'Fix them in the editor to play it.',
              ItemNotFoundException() => 'This quiz no longer exists.',
              _ => 'Could not start the quiz: $error',
            }, textAlign: TextAlign.center),
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Player extends ConsumerStatefulWidget {
  const _Player({required this.quizId, required this.state});

  final String quizId;
  final PlayerState state;

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> {
  /// Set once the attempt is over, so leaving no longer asks.
  bool _finished = false;

  /// True while one of our confirmation dialogs is open, so running out of
  /// time can close it.
  bool _dialogOpen = false;

  /// Redraws the countdown; only runs when the quiz has a time limit.
  Timer? _ticker;

  /// Stops the clock while the app is hidden (in the background on Android,
  /// minimized on Windows).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () => _controller.pause(),
    onShow: () => _controller.resume(),
  );

  PlayerController get _controller =>
      ref.read(playerProvider(widget.quizId).notifier);

  PlayerState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    if (_state.quiz.settings.timeLimitSeconds != null) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _tick(),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _finished) return;
    final state = ref.read(playerProvider(widget.quizId)).value;
    if (state != null && state.isTimeUp(ref.read(playerClockProvider).now())) {
      _onTimeUp();
    } else {
      setState(() {});
    }
  }

  void _onTimeUp() {
    _ticker?.cancel();
    // Dialogs live on the root navigator, above the player's own.
    if (_dialogOpen) Navigator.of(context, rootNavigator: true).pop();
    _finish(timeUp: true);
  }

  Future<T?> _showDialog<T>(WidgetBuilder builder) async {
    _dialogOpen = true;
    try {
      return await showDialog<T>(context: context, builder: builder);
    } finally {
      _dialogOpen = false;
    }
  }

  void _nextOrFinish() => _state.isLast ? _finish() : _controller.next();

  Future<void> _finish({bool timeUp = false}) async {
    if (_finished) return;
    final unanswered = _state.unansweredCount;
    if (unanswered > 0 && !timeUp) {
      final finish = await _showDialog<bool>(
        (context) => AlertDialog(
          title: const Text('Finish quiz?'),
          content: Text(
            unanswered == 1
                ? "You haven't answered 1 question. It will count as skipped."
                : "You haven't answered $unanswered questions. "
                      'They will count as skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      if (!(finish ?? false) || !mounted || _finished) return;
    }

    _ticker?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    AttemptScore score;
    try {
      final (_, attempt) = await _controller.finishAndSave();
      score = attempt.score;
    } catch (e) {
      // The attempt is over either way; show the score even if saving failed.
      score = ref.read(playerProvider(widget.quizId)).requireValue.score;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save this attempt: $e')),
      );
    }
    if (!mounted) return;
    setState(() => _finished = true);
    // TODO(#25): show the results screen instead.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${timeUp ? "Time's up · " : ''}'
          '${score.passed ? 'Passed' : 'Not passed'}',
        ),
        content: Text(
          '${score.points} / ${score.maxPoints} points '
          '(${score.percent.round()}%)\n'
          '${score.correct} correct · ${score.incorrect} incorrect · '
          '${score.skipped} skipped',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    final leave = await _showDialog<bool>(
      (context) => AlertDialog(
        title: const Text('Leave quiz?'),
        content: const Text('Your answers in this attempt will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) {
      setState(() => _finished = true);
      Navigator.of(context).pop();
    }
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    for (var n = 1; n <= 9; n++) ...{
      SingleActivator(_digitKeys[n - 1]): () => _controller.selectAt(n - 1),
      SingleActivator(_numpadKeys[n - 1]): () => _controller.selectAt(n - 1),
    },
    const SingleActivator(LogicalKeyboardKey.enter): _nextOrFinish,
    const SingleActivator(LogicalKeyboardKey.numpadEnter): _nextOrFinish,
    const SingleActivator(LogicalKeyboardKey.arrowRight): _controller.next,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): _controller.previous,
  };

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final question = state.current;
    final total = state.questions.length;
    final theme = Theme.of(context);
    final isSingle = question.type == QuestionType.single;

    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: CallbackShortcuts(
        bindings: _shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(state.quiz.title),
              actions: [
                if (state.remainingMs(ref.read(playerClockProvider).now())
                    case final remaining?)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _Countdown(remainingMs: remaining),
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (state.index + 1) / total,
                  semanticsLabel: 'Progress',
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Question ${state.index + 1} of $total · '
                  '${state.answeredCount} answered',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(question.prompt, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  isSingle ? 'Choose one answer' : 'Choose all that apply',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (isSingle)
                  RadioGroup<String>(
                    groupValue: state.currentSelection.firstOrNull,
                    onChanged: (id) {
                      if (id != null) _controller.select(id);
                    },
                    child: Column(
                      children: [
                        for (final (i, option) in state.currentOptions.indexed)
                          RadioListTile<String>(
                            value: option.id,
                            title: Text('${i + 1}. ${option.text}'),
                          ),
                      ],
                    ),
                  )
                else
                  for (final (i, option) in state.currentOptions.indexed)
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      value: state.currentSelection.contains(option.id),
                      onChanged: (_) => _controller.select(option.id),
                      title: Text('${i + 1}. ${option.text}'),
                    ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: state.isFirst ? null : _controller.previous,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _controller.skip,
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _nextOrFinish,
                      child: Text(state.isLast ? 'Finish' : 'Next'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const _numpadKeys = [
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// Time left, as `m:ss`; red in the last minute.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remainingMs});

  final int remainingMs;

  @override
  Widget build(BuildContext context) {
    final seconds = (remainingMs / 1000).ceil();
    final text =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final urgent = seconds <= 60;
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        Icons.timer_outlined,
        size: 18,
        color: urgent ? scheme.onErrorContainer : null,
      ),
      label: Text(
        text,
        semanticsLabel: '$seconds seconds left',
        style: urgent ? TextStyle(color: scheme.onErrorContainer) : null,
      ),
      backgroundColor: urgent ? scheme.errorContainer : null,
    );
  }
}
