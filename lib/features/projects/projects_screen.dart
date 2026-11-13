import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:witrack/core/theme/witrack_theme.dart';
import 'package:witrack/core/widgets/witrack_surface.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/features/dashboard/project_time_tree.dart';
import 'package:witrack/features/projects/project_dialogs.dart';
import 'package:witrack/features/tracking/tracking_confirm.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingControllerProvider);
    final workspaceId = tracking.workspaceId;
    final theme = Theme.of(context);

    if (workspaceId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final projects = ref.watch(projectsProvider(workspaceId));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search projects',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => showCreateProjectDialog(
                      context,
                      ref,
                      workspaceId: workspaceId,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New project'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: projects.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (rows) {
                    final filtered = rows
                        .where((p) => p.name.toLowerCase().contains(_query))
                        .toList();
                    if (filtered.isEmpty) {
                      return const Center(child: Text('No projects found.'));
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        return WitrackSurface(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(
                                int.parse(
                                      project.color.substring(1),
                                      radix: 16,
                                    ) +
                                    0xFF000000,
                              ),
                            ),
                            title: Text(
                              project.name,
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              'Created ${DateFormat.yMMMd().add_Hm().format(project.createdAt.toLocal())}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme
                                            .extension<WitrackThemeExtras>()
                                            ?.highlight ??
                                        theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(
                                          trackingControllerProvider.notifier,
                                        )
                                        .selectProject(
                                          projectId: project.id,
                                          projectName: project.name,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Selected ${project.name}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Select'),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final stopped =
                                        await confirmAndStopOpenTimer(
                                      context: context,
                                      ref: ref,
                                      actionLabel: 'delete this project',
                                    );
                                    if (!stopped) return;
                                    await ref
                                        .read(projectRepositoryProvider)
                                        .archiveProject(project.id);
                                    await ref
                                        .read(
                                          trackingControllerProvider.notifier,
                                        )
                                        .retargetAfterProjectGone(project.id);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
