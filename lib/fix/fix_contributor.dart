import 'package:analyzer_plugin/utilities/fixes/fix_contributor_mixin.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

class MyFixContributor extends Object
    with FixContributorMixin
    implements FixContributor {
  static FixKind defineComponent =
      FixKind('defineComponent', 100, "Define a component named {0}");
  String path;

  MyFixContributor(this.path);

  AnalysisSession get session => request.result.session;

  @override
  Future<void> computeFixesForError(AnalysisError error) async {
    ErrorCode code = error.errorCode;
    if (code == AnalysisError.ERROR_CODE_COMPARATOR) {
      await _defineComponent(error);
      await _useExistingComponent(error);
    }
  }

  Future<void> _defineComponent(AnalysisError error) async {
    // TODO Get the name from the source code.
    String componentName = null;
    ChangeBuilder builder = ChangeBuilder();
    builder.addFileEdit(path, (FileEditBuilder builder) {
      // TODO Build the edit to insert the definition of the component.
    });
    addFix(error, defineComponent, builder, args: [componentName]);
  }

  Future<void> _useExistingComponent(AnalysisError error) async {
    // ...
  }
}
