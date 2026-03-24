import '../../domain/repositories/idea_repository.dart';
import '../../domain/repositories/status_repository.dart';
import '../../domain/repositories/todo_repository.dart';
import '../../models/activity/hourly_record.dart';
import '../../models/event/todo_item.dart';
import '../../models/idea/idea_session.dart';
import '../../models/transfer/transfer_snapshot.dart';
import '../../services/transfer_api_client.dart';
import '../local/local_idea_repository.dart';
import '../local/local_status_repository.dart';
import '../local/local_todo_repository.dart';
import '../remote/in_memory_cache.dart';
import '../remote/remote_idea_repository.dart';
import '../remote/remote_status_repository.dart';
import '../remote/remote_todo_repository.dart';

enum RepositoryMode { local, remote }

class RepositoryFacade {
  RepositoryFacade._();

  static final LocalStatusRepository _localStatus = LocalStatusRepository();
  static final LocalTodoRepository _localTodo = LocalTodoRepository();
  static final LocalIdeaRepository _localIdea = LocalIdeaRepository();

  static final InMemoryCache _remoteCache = InMemoryCache();
  static final RemoteStatusRepository _remoteStatus = RemoteStatusRepository(
    _remoteCache,
  );
  static final RemoteTodoRepository _remoteTodo = RemoteTodoRepository(
    _remoteCache,
  );
  static final RemoteIdeaRepository _remoteIdea = RemoteIdeaRepository(
    _remoteCache,
  );

  static TransferApiClient? _transferApiClient;
  static RepositoryMode _mode = RepositoryMode.local;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;
  static RepositoryMode get mode => _mode;

  static StatusRepository get status =>
      _mode == RepositoryMode.remote ? _remoteStatus : _localStatus;

  static TodoRepository get todo =>
      _mode == RepositoryMode.remote ? _remoteTodo : _localTodo;

  static IdeaRepository get idea =>
      _mode == RepositoryMode.remote ? _remoteIdea : _localIdea;

  static Future<void> init() async {
    if (_initialized) return;
    await _localStatus.init();
    await _localTodo.init();
    await _localIdea.init();
    _initialized = true;
  }

  static void switchMode(RepositoryMode mode) {
    _mode = mode;
  }

  static void configureTransferClient({required String baseUrl}) {
    _transferApiClient?.dispose();
    _transferApiClient = TransferApiClient(baseUrl: baseUrl);
  }

  static Future<TransferChannelInfo> createTransferChannel({
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final client = _transferApiClient;
    if (client == null) {
      throw TransferApiException('未配置中转服务地址');
    }
    final channel = await client.createChannel(ttl: ttl);
    _remoteCache.boundChannelId = channel.channelId;
    return channel;
  }

  static Future<bool> pullRemoteSnapshot({
    required String channelId,
    required String token,
  }) async {
    final client = _transferApiClient;
    if (client == null) {
      throw TransferApiException('未配置中转服务地址');
    }
    final snapshot = await client.pullData(channelId: channelId, token: token);
    if (snapshot == null) return false;
    applySnapshotToRemote(snapshot);
    return true;
  }

  static void applySnapshotToRemote(TransferSnapshot snapshot) {
    _remoteCache.ideaSessions = Map<String, IdeaSession>.from(
      snapshot.ideaSessions,
    );
    _remoteCache.currentIdeaSessionId = snapshot.currentIdeaSessionId;
    _remoteCache.todos = List<TodoItem>.from(snapshot.todos);
    _remoteCache.statusByDate = Map<String, List<HourlyRecord>>.from(
      snapshot.statusByDate,
    );
    _remoteCache.lastSyncedAt = DateTime.now();
  }

  static Future<void> expireTransferChannel({
    required String channelId,
    required String token,
  }) async {
    final client = _transferApiClient;
    if (client == null) return;
    await client.expireChannel(channelId: channelId, token: token);
  }

  static void clearRemoteCache() {
    _remoteCache.clearAll();
  }

  static TransferSnapshot buildLocalSnapshot() {
    return TransferSnapshot(
      ideaSessions: _localIdea.exportAllSessions(),
      currentIdeaSessionId: _localIdea.getCurrentSessionId(),
      todos: _localTodo.exportAll(),
      statusByDate: _localStatus.exportAllByDate(),
    );
  }

  static Future<void> pushLocalSnapshot({
    required String channelId,
    required String token,
  }) async {
    final client = _transferApiClient;
    if (client == null) {
      throw TransferApiException('未配置中转服务地址');
    }
    final snapshot = buildLocalSnapshot();
    await client.pushData(
      channelId: channelId,
      token: token,
      snapshot: snapshot,
    );
  }
}
