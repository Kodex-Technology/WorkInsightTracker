import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:witrack/data/providers.dart';
import 'package:witrack/features/tracking/tracking_controller.dart';

Future<void> showCreateProjectDialog(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
}) async {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  var color = '#6366F1';
  final formKey = GlobalKey<FormState>();

  final created = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create project'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Project name',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final c in const [
                            '#6366F1',
                            '#14B8A6',
                            '#F59E0B',
                            '#F43F5E',
                            '#8B5CF6',
                          ])
                            InkWell(
                              onTap: () => setState(() => color = c),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Color(
                                    int.parse(c.substring(1), radix: 16) +
                                        0xFF000000,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color == c
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final project =
                      await ref.read(projectRepositoryProvider).createProject(
                            workspaceId: workspaceId,
                            name: nameController.text.trim(),
                            color: color,
                          );
                  // Project only — user must create a task before Start is enabled.
                  ref
                      .read(trackingControllerProvider.notifier)
                      .selectProjectOnly(
                        projectId: project.id,
                        projectName: project.name,
                      );
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                child: const Text('Create Project'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  descController.dispose();
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project created')),
    );
  }
}

Future<void> showCreateTaskDialog(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
}) async {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final created = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Create task'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Task name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(projectRepositoryProvider);
              final task = await repo.createTask(
                projectId: projectId,
                name: nameController.text.trim(),
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );
              final project = await repo.getProject(projectId);
              final live = ref.read(trackingControllerProvider);
              final projectName = project?.name ??
                  (live.projectId == projectId ? live.projectName : null) ??
                  'Project';
              await ref.read(trackingControllerProvider.notifier).focusWork(
                    projectId: projectId,
                    projectName: projectName,
                    taskId: task.id,
                    taskName: task.name,
                    startIfStopped: false,
                  );
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Create Task'),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  notesController.dispose();
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task created')),
    );
  }
}
