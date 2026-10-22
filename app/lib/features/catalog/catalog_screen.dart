import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';
import '../../data/remote/api_client.dart';
import '../../data/repositories/providers.dart';
import '../../data/database/app_database.dart' show LibraryOrigin;

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _tag = TextEditingController();
  Timer? _debounce;
  String _kind = 'quizzes';
  String _sort = 'newest';
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  int _page = 1;
  int _generation = 0;
  bool _busy = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < 240 &&
          !_busy &&
          _more) {
        _load();
      }
    });
    scheduleMicrotask(_load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _reset() {
    _generation++;
    setState(() {
      _page = 1;
      _items = [];
      _selected = null;
      _more = true;
      _busy = false;
    });
    _load();
  }

  void _queryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reset);
  }

  Future<void> _load() async {
    if (_busy || !_more) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = await ref.read(apiClientProvider.future);
      final result =
          await api.request(
                'GET',
                '/$_kind',
                query: {
                  'q': _search.text.trim(),
                  'tag': _tag.text.trim(),
                  'sort': _sort,
                  'page': _page,
                },
                authenticated: false,
              )
              as Map<String, dynamic>;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll((result['items'] as List).cast<Map<String, dynamic>>());
        _more = result['hasMore'] as bool;
        _page++;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    try {
      final api = await ref.read(apiClientProvider.future);
      final data =
          await api.request(
                'GET',
                '/$_kind/${item['id']}',
                authenticated: false,
              )
              as Map<String, dynamic>;
      var owned = false;
      if (await api.isSignedIn) {
        try {
          final profile =
              await api.request('GET', '/me') as Map<String, dynamic>;
          owned = profile['id'] == item['ownerId'];
        } on ApiFailure {
          /* Public downloads remain available with an expired session. */
        }
      }
      final document = parseDocument(data);
      if (document is QuizDocument) {
        await ref
            .read(quizRepositoryProvider)
            .storeRemote(
              document.quiz,
              remoteId: item['id'] as String,
              remoteVersion: data['version'] as int,
              ownerName: item['ownerName'] as String,
              owned: owned,
              origin: LibraryOrigin.downloaded,
            );
      } else if (document is DeckDocument) {
        await ref
            .read(deckRepositoryProvider)
            .storeRemote(
              document.deck,
              remoteId: item['id'] as String,
              remoteVersion: data['version'] as int,
              ownerName: item['ownerName'] as String,
              owned: owned,
              origin: LibraryOrigin.downloaded,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded to your library')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _detail(Map<String, dynamic> item) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        item['title'] as String,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(item['description'] as String),
      const SizedBox(height: 12),
      Text(
        'By ${item['ownerName']} · ${item['itemCount']} ${_kind == 'quizzes' ? 'questions' : 'cards'} · ${item['downloadCount']} downloads',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          for (final tag in item['tags'] as List) Chip(label: Text('$tag')),
        ],
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => _download(item),
        icon: const Icon(Icons.download),
        label: const Text('Download'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Catalog')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'quizzes', label: Text('Quizzes')),
                  ButtonSegment(value: 'decks', label: Text('Decks')),
                ],
                selected: {_kind},
                onSelectionChanged: (value) {
                  _kind = value.single;
                  _reset();
                },
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search catalog',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _queryChanged,
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _tag,
                  decoration: const InputDecoration(labelText: 'Tag filter'),
                  onChanged: _queryChanged,
                ),
              ),
              DropdownButton<String>(
                value: _sort,
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(
                    value: 'downloads',
                    child: Text('Most downloaded'),
                  ),
                ],
                onChanged: (value) {
                  _sort = value!;
                  _reset();
                },
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final list = _items.isEmpty && !_busy && _error == null
                  ? const Center(child: Text('No matching content.'))
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _items.length + (_more ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return Center(
                            child: _busy
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  )
                                : TextButton(
                                    onPressed: _load,
                                    child: const Text('Load more'),
                                  ),
                          );
                        }
                        final item = _items[index];
                        return ListTile(
                          title: Text(item['title'] as String),
                          subtitle: Text(
                            '${item['ownerName']} · ${item['itemCount']} items · ${item['downloadCount']} downloads',
                          ),
                          selected: _selected?['id'] == item['id'],
                          onTap: () {
                            if (wide) {
                              setState(() => _selected = item);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Catalog details'),
                                    ),
                                    body: _detail(item),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: list),
                        const VerticalDivider(),
                        Expanded(
                          child: _selected == null
                              ? const Center(
                                  child: Text(
                                    'Select an item to see its details.',
                                  ),
                                )
                              : _detail(_selected!),
                        ),
                      ],
                    )
                  : list;
            },
          ),
        ),
      ],
    ),
  );
}
