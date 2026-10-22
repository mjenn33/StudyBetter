import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../json_response.dart';

/// Shared, parameterized public catalog query. Table names are internal only.
Future<Response> catalogResponse(
  Connection connection,
  String table,
  Request request,
) async {
  assert(table == 'quizzes' || table == 'decks');
  final query = request.url.queryParameters;
  final page = int.tryParse(query['page'] ?? '1');
  final sort = query['sort'] ?? 'newest';
  if (page == null ||
      page < 1 ||
      page > 1000000 ||
      !{'newest', 'downloads'}.contains(sort)) {
    return jsonResponse({
      'error': 'Invalid page or sort (newest, downloads).',
    }, statusCode: 400);
  }
  final ordering = sort == 'downloads'
      ? 'c.download_count DESC, c.id'
      : 'c.created_at DESC, c.id';
  final rows = await connection.execute(
    Sql.named('''
    SELECT c.id, c.title, c.description, c.tags, c.language, c.version,
           c.item_count, c.download_count, c.created_at, c.updated_at,
           u.username, c.owner_id
    FROM $table c JOIN users u ON u.id = c.owner_id
    WHERE c.visibility = 'public'
      AND (@q = '' OR c.search_vector @@ plainto_tsquery('simple', @q))
      AND (@tag = '' OR @tag = ANY(c.tags))
    ORDER BY $ordering LIMIT 21 OFFSET @offset
  '''),
    parameters: {
      'q': query['q']?.trim() ?? '',
      'tag': query['tag']?.trim() ?? '',
      'offset': (page - 1) * 20,
    },
  );
  return jsonResponse({
    'page': page,
    'hasMore': rows.length > 20,
    'items': [
      for (final row in rows.take(20))
        {
          'id': row[0],
          'title': row[1],
          'description': row[2],
          'tags': row[3],
          'language': row[4],
          'version': row[5],
          'itemCount': row[6],
          'downloadCount': row[7],
          'createdAt': (row[8] as DateTime).toUtc().toIso8601String(),
          'updatedAt': (row[9] as DateTime).toUtc().toIso8601String(),
          'ownerName': row[10],
          'ownerId': row[11],
        },
    ],
  });
}
