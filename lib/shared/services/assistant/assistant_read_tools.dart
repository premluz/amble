import 'assistant_backend.dart';
import 'assistant_read_queries.dart';
import 'assistant_tool.dart';

const _range = {
  'from': {'type': 'string', 'description': 'First day, YYYY-MM-DD (local).'},
  'to': {'type': 'string', 'description': 'Last day, YYYY-MM-DD, inclusive.'},
};

/// The tools that only look. Safe at every permission level.
List<AssistantTool> assistantReadTools(AssistantBackend backend) {
  final reads = AssistantReads(backend);
  return [
    AssistantTool(
      name: 'get_day',
      description:
          'Everything on one day in Amble: tasks, imported calendar events '
          '(read-only), zones (named blocks of time like "Focus") and free '
          'time of 15 minutes or more. Times are local.',
      inputSchema: _schema(
        {
          'date': {'type': 'string', 'description': 'YYYY-MM-DD (local).'},
        },
        required: ['date'],
      ),
      run: reads.getDay,
    ),
    AssistantTool(
      name: 'list_tasks',
      description:
          'Tasks scheduled between two dates, oldest first. Use '
          'important_only for "what matters" questions. At most '
          '${AssistantLimits.maxRangeDays} days.',
      inputSchema: _schema(
        {
          ..._range,
          'important_only': {'type': 'boolean'},
        },
        required: ['from', 'to'],
      ),
      run: reads.listTasks,
    ),
    AssistantTool(
      name: 'get_availability',
      description:
          'Free time between two dates, already excluding tasks and imported '
          'calendar events, within planning hours (default 07:00-22:00). '
          'Use this to find slots, e.g. "four one-hour slots this week": '
          'min_minutes 60, then choose four. Pass zone_name to keep only '
          'time inside that zone. At most ${AssistantLimits.maxRangeDays} '
          'days.',
      inputSchema: _schema(
        {
          ..._range,
          'min_minutes': {'type': 'integer', 'description': 'Default 30.'},
          'zone_name': {'type': 'string'},
          'day_start_hour': {'type': 'integer', 'description': 'Default 7.'},
          'day_end_hour': {'type': 'integer', 'description': 'Default 22.'},
        },
        required: ['from', 'to'],
      ),
      run: reads.availability,
    ),
    AssistantTool(
      name: 'list_zones',
      description:
          'Zones (named blocks of time such as "Focus" or "Family") on each '
          'day between two dates.',
      inputSchema: _schema(_range, required: ['from', 'to']),
      run: reads.listZones,
    ),
    AssistantTool(
      name: 'list_categories',
      description: 'The labels a task can have, e.g. Work or Health.',
      inputSchema: _schema(const {}, required: const []),
      run: reads.listCategories,
    ),
  ];
}

Map<String, Object?> _schema(
  Map<String, Object?> properties, {
  required List<String> required,
}) => {'type': 'object', 'properties': properties, 'required': required};
