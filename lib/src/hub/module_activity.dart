import 'package:flutter/widgets.dart';

/// Hidden modules retain routes and analysis state, but file decoders pause.
/// The physical camera remains owned by the application, never by this scope.
class ModuleActivity extends InheritedWidget {
  const ModuleActivity({required this.active, required super.child, super.key});
  final bool active;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModuleActivity>()?.active ??
      true;
  @override
  bool updateShouldNotify(ModuleActivity oldWidget) =>
      active != oldWidget.active;
}
