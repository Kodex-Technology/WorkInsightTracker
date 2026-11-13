import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:witrack/data/database/app_database.dart';

class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<String> ensureDefaultWorkspace(String userId) async {
    final existing = await (_db.select(_db.workspaces)
          ..where((t) => t.userId.equals(userId)))
        .get();
    if (existing.isNotEmpty) return existing.first.id;

    final id = _uuid.v4();
    await _db.into(_db.workspaces).insert(
          WorkspacesCompanion.insert(
            id: id,
            userId: userId,
            name: 'Personal',
            createdAt: DateTime.now().toUtc(),
          ),
        );
    return id;
  }

  Future<Client> createClient({
    required String workspaceId,
    required String name,
  }) {
    return _db.into(_db.clients).insertReturning(
          ClientsCompanion.insert(
            id: _uuid.v4(),
            workspaceId: workspaceId,
            name: name,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<Project> createProject({
    required String workspaceId,
    required String name,
    String? clientId,
    String color = '#6366F1',
  }) {
    return _db.into(_db.projects).insertReturning(
          ProjectsCompanion.insert(
            id: _uuid.v4(),
            workspaceId: workspaceId,
            name: name,
            clientId: Value(clientId),
            color: Value(color),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<Task> createTask({
    required String projectId,
    required String name,
    String? notes,
  }) {
    return _db.into(_db.tasks).insertReturning(
          TasksCompanion.insert(
            id: _uuid.v4(),
            projectId: projectId,
            name: name,
            notes: Value(notes),
            status: const Value('open'),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Open (trackable) tasks only — completed/archived stay out of the active list.
  Stream<List<Task>> watchTasks(String projectId) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.projectId.equals(projectId) &
                t.archived.equals(false) &
                t.status.equals('open'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Completed (not deleted) tasks for a project — separate history list.
  Stream<List<Task>> watchCompletedTasks(String projectId) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.projectId.equals(projectId) &
                t.archived.equals(false) &
                t.status.equals('completed'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<Task>> listOpenTasks(String projectId) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.projectId.equals(projectId) &
                t.archived.equals(false) &
                t.status.equals('open'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// First open task if any — never auto-creates. User must create tasks.
  Future<Task?> firstOpenTask(String projectId) async {
    final open = await listOpenTasks(projectId);
    if (open.isEmpty) return null;
    return open.first;
  }

  Stream<List<Project>> watchActiveProjects(String workspaceId) {
    return (_db.select(_db.projects)
          ..where(
            (t) =>
                t.workspaceId.equals(workspaceId) & t.archived.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<Project?> getProject(String id) {
    return (_db.select(_db.projects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Task?> getTask(String id) {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> archiveProject(String id) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
          const ProjectsCompanion(archived: Value(true)),
        );
    await (_db.update(_db.tasks)..where((t) => t.projectId.equals(id))).write(
          const TasksCompanion(archived: Value(true)),
        );
  }

  Future<void> archiveTask(String id) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          const TasksCompanion(archived: Value(true)),
        );
  }

  Future<void> markTaskCompleted(String id) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          const TasksCompanion(status: Value('completed')),
        );
  }

  Future<void> reopenTask(String id) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          const TasksCompanion(
            status: Value('open'),
            archived: Value(false),
          ),
        );
  }
}
