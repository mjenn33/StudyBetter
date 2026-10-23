import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/providers.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/owned_content_restore.dart';
import '../../app/preferences.dart';
import '../account/account_screen.dart';

/// Personal study preferences stored on this device.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(newCardsPerDayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: switch (limit) {
        AsyncData(:final value) => ListView(
          children: [
            ListTile(
              title: const Text('Appearance'),
              trailing: DropdownButton<ThemeMode>(
                value: ref.watch(themeModeProvider).value ?? ThemeMode.system,
                items: [
                  for (final mode in ThemeMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.name)),
                ],
                onChanged: (mode) async {
                  if (mode == null) return;
                  await ref
                      .read(settingsRepositoryProvider)
                      .write('themeMode', mode.name);
                  ref.invalidate(themeModeProvider);
                },
              ),
            ),
            ListTile(
              title: const Text('Account'),
              subtitle: const Text(
                'Sign in or create an account to publish content.',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
              ),
            ),
            ListTile(
              title: const Text('Sign out'),
              onTap: () async {
                await (await ref.read(apiClientProvider.future)).logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Signed out')));
                }
              },
            ),
            ListTile(
              title: const Text('Restore my published content'),
              subtitle: const Text(
                'Download your quizzes and decks without overwriting local edits.',
              ),
              onTap: () => _restorePublishedContent(context, ref),
            ),
            ListTile(
              title: const Text('Server address'),
              subtitle: Text(ref.watch(serverUrlProvider).value ?? 'Loading…'),
              onTap: () async {
                final current = await ref.read(serverUrlProvider.future);
                if (!context.mounted) return;
                final saved = await showDialog<String>(
                  context: context,
                  builder: (context) => _ServerUrlDialog(initial: current),
                );
                if (saved != null) {
                  await ref
                      .read(settingsRepositoryProvider)
                      .write('serverUrl', saved);
                  ref.invalidate(serverUrlProvider);
                }
              },
            ),
            ListTile(
              title: const Text('New cards per day'),
              subtitle: const Text(
                'Maximum new cards included in due study sessions.',
              ),
              trailing: DropdownButton<int>(
                value: value,
                items: [10, 20, 30, 50, 100]
                    .map(
                      (number) => DropdownMenuItem(
                        value: number,
                        child: Text('$number'),
                      ),
                    )
                    .toList(),
                onChanged: (number) async {
                  if (number == null) return;
                  await ref
                      .read(settingsRepositoryProvider)
                      .setNewCardsPerDay(number);
                  ref.invalidate(newCardsPerDayProvider);
                },
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

Future<void> _restorePublishedContent(
  BuildContext context,
  WidgetRef ref,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Restoring your published content…')),
        ],
      ),
    ),
  );
  try {
    final result = await restoreOwnedContent(
      api: await ref.read(apiClientProvider.future),
      quizzes: ref.read(quizRepositoryProvider),
      decks: ref.read(deckRepositoryProvider),
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final details = [
      'Restored ${result.restored} item${result.restored == 1 ? '' : 's'}.',
      if (result.skipped > 0)
        '${result.skipped} with newer local edits ${result.skipped == 1 ? 'was' : 'were'} kept.',
      if (result.failed > 0)
        '${result.failed} could not be restored.',
    ].join(' ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(details)));
  } catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
}

class _ServerUrlDialog extends StatefulWidget {
  const _ServerUrlDialog({required this.initial});
  final String initial;
  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        _controller.text.trim().replaceFirst(RegExp(r'/+$'), ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('API base URL'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'https://example.com/api/v1',
          labelText: 'Server URL',
        ),
        validator: (value) {
          final uri = Uri.tryParse(value?.trim() ?? '');
          return uri != null &&
                  {'http', 'https'}.contains(uri.scheme) &&
                  uri.host.isNotEmpty &&
                  uri.userInfo.isEmpty &&
                  !uri.hasQuery &&
                  !uri.hasFragment
              ? null
              : 'Enter a valid HTTP or HTTPS URL.';
        },
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
