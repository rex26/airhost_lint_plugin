import 'dart:developer';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:airhost_lint_plugin/logger/log.dart';
import 'package:_fe_analyzer_shared/src/scanner/token.dart';

class MirrorChecker {
  final CompilationUnit _compilationUnit;
  String unitPath;

  MirrorChecker(this._compilationUnit) {
    unitPath = this._compilationUnit.declaredElement.source.fullName;
    // unitPath = this._compilationUnit.declaredElement.librarySource.fullName;
    // unitPath = this._compilationUnit.declaredElement.uri;
    mirrorLog.info("checker $unitPath");
  }

  Iterable<MirrorCheckerIssue> enumToStringErrors() {
    final visitor = _MirrorVisitor();
    visitor.unitPath = unitPath;
    _compilationUnit.accept(visitor);
    return visitor.issues;
  }
}

class _MirrorVisitor extends RecursiveAstVisitor<void> {
  String unitPath;
  final _issues = <MirrorCheckerIssue>[];

  Iterable<MirrorCheckerIssue> get issues => _issues;
  bool kDebugMode = true;

  @override
  void visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    if (_isModuleL10nFile(unitPath)) {
      String importPath = node.selectedUriContent;
      mirrorLog.info("-> import $importPath");
      if (importPath.contains(r'intl/messages_all.dart')) {
        _issues.add(
          MirrorCheckerIssue(
            plugin.AnalysisErrorSeverity.WARNING,
            plugin.AnalysisErrorType.LINT,
            node.offset,
            node.length,
            '可能不需要这个import',
            '',
          ),
        );
      } else if (importPath.contains(r'package:intl/intl.dart')) {
        String posTip = "import 'package:airhost_pos/l10n/pos_intl.dart';";
        String coreTip = "import 'package:airhost_core/l10n/core_intl.dart';";
        String l10nPath =
            '${Platform.pathSeparator}lib${Platform.pathSeparator}generated${Platform.pathSeparator}l10n.dart';
        String tip = "";
        if (unitPath.endsWith('onestay_pos$l10nPath')) {
          tip = posTip;
        } else if (unitPath.endsWith('onestay_core$l10nPath')) {
          tip = coreTip;
        }
        if (kDebugMode) {
          tip = "测试项目的提醒: $posTip";
        }
        if (tip.isNotEmpty) {
          _issues.add(
            MirrorCheckerIssue(
              plugin.AnalysisErrorSeverity.ERROR,
              plugin.AnalysisErrorType.LINT,
              node.offset,
              node.length,
              '需要替换为:$tip',
              tip,
            ),
          );
        }
      }
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);

    var element = node.declaredElement;
    String elementName = element?.displayName ?? '';
    bool isStatic = element?.isStatic ?? false;
    bool isPublic = element?.isPublic ?? false;

    String paramType = '';
    String paramsValue = '';
    var parameters = node?.parameters?.parameters;
    if (1 == (parameters?.length ?? 0)) {
      paramType = parameters.first.declaredElement?.type
          ?.getDisplayString(withNullability: true);
      paramsValue = parameters.first.declaredElement?.displayName ?? '';
    }
    String returnType =
        element?.returnType?.getDisplayString(withNullability: true) ?? false;

    if ((_isModuleL10nFile(unitPath)) &&
        isStatic &&
        isPublic &&
        'Future<T*>*' == returnType &&
        'Locale*' == paramType &&
        'load' == elementName) {
      bool onlyOneStatement = true;
      if (node.body is BlockFunctionBody) {
        BlockFunctionBody body = node.body as BlockFunctionBody;
        int statements = body?.block?.statements?.length ?? 0;
        if (1 != statements) {
          onlyOneStatement = false;
        }
        mirrorLog.info("=> statements $statements");
      }
      var expectedStatement =
          node.body?.toSource()?.contains(r'Intl.load(') ?? false;
      if (!onlyOneStatement || !expectedStatement) {
        _issues.add(
          MirrorCheckerIssue(
            plugin.AnalysisErrorSeverity.ERROR,
            plugin.AnalysisErrorType.LINT,
            node.offset,
            node.length,
            '需要将函数体替换为: Intl.load($paramsValue)',
            'static Future<T> load(Locale locale) => Intl.load(locale);',
          ),
        );
      }

      _printTestInfo(element, node, elementName, isStatic, returnType, paramType,
          paramsValue);
    }
  }

  void _printTestInfo(
      ExecutableElement element,
      MethodDeclaration node,
      String elementName,
      bool isStatic,
      String returnType,
      String paramType,
      String paramsValue) {
    String libraryName = element?.librarySource?.fullName ?? '';
    String libraryUri = element?.librarySource?.uri?.toString() ?? '';
    String declarationName = element?.declaration?.displayName ?? '';
    String functionBody = node.body.toSource();
    String bodyType = node.body.runtimeType.toString();
    mirrorLog.info("=> bodyType $bodyType");
    mirrorLog.info("=> elementName $elementName");
    mirrorLog.info("isStatic $isStatic");
    mirrorLog.info("returnType $returnType");
    mirrorLog.info("libraryName $libraryName");
    mirrorLog.info("libraryUri $libraryUri");
    mirrorLog.info("declarationName $declarationName");
    mirrorLog.info("paramType $paramType");
    mirrorLog.info("paramsValue $paramsValue");
    mirrorLog.info("<= functionBody $functionBody");

    node.body =
        astFactory.emptyFunctionBody(StringToken(TokenType.STRING, ';;;', 0));

    mirrorLog.info("<= functionBody2 ${node.body.toSource()}");
  }
}

bool _isModuleL10nFile(String url) {
  String l10nPath =
      '${Platform.pathSeparator}lib${Platform.pathSeparator}generated${Platform.pathSeparator}l10n.dart';
  return url.endsWith(l10nPath) ||
      url.endsWith('onestay_pos$l10nPath') ||
      url.endsWith('onestay_core$l10nPath');
}

class MirrorCheckerIssue {
  final plugin.AnalysisErrorSeverity analysisErrorSeverity;
  final plugin.AnalysisErrorType analysisErrorType;
  final int offset;
  final int length;
  final String message;
  final String code;

  MirrorCheckerIssue(
    this.analysisErrorSeverity,
    this.analysisErrorType,
    this.offset,
    this.length,
    this.message,
    this.code,
  );
}

String _getParamType(MethodDeclaration node) {
  String paramsValue = '';
  String paramsName = '';
  String typeParam = '';
  var nodeList = node?.parameters?.parameters;
  if (nodeList?.isNotEmpty ?? false) {
    paramsValue = nodeList?.first?.declaredElement?.displayName ?? '';
    var covariantKeyword = nodeList?.first?.covariantKeyword?.stringValue ?? '';
    final kind = nodeList?.first?.kind?.name ?? '';
    final identifier = nodeList?.first?.identifier?.name ?? '';
    String paramType = nodeList?.first?.declaredElement?.type
        ?.getDisplayString(withNullability: true);

    final toSource = nodeList?.first?.toSource() ?? '';
    final beginToken = nodeList?.first?.beginToken?.stringValue ?? '';
    String identifierType = nodeList?.first?.identifier?.staticType
            ?.getDisplayString(withNullability: true) ??
        '';
    String staticElement =
        nodeList?.first?.identifier?.staticElement?.displayName ?? '';

    final typeParametersFirst = node.typeParameters?.typeParameters?.first;
    String tyeNameName = typeParametersFirst?.name?.staticType
            ?.getDisplayString(withNullability: true) ??
        '';
    String declaredElementName =
        typeParametersFirst?.declaredElement?.displayName ?? '';
    String bound = typeParametersFirst?.bound?.toSource() ?? '';
    String extendsKeyword =
        typeParametersFirst?.extendsKeyword?.stringValue ?? '';
    String typeBeginToken = typeParametersFirst?.beginToken?.stringValue ?? '';
    paramsName =
        'covariantKeyword:$covariantKeyword kind:$kind identifier:$identifier toSource:$toSource beginToken:$beginToken identifierType:$identifierType, staticElement:$staticElement declaredElementSource:$paramType';
    typeParam =
        'tyeNameName:$tyeNameName, declaredElementName:$declaredElementName, bound:$bound, extendsKeyword:$extendsKeyword, typeBeginToken:$typeBeginToken';

    mirrorLog.info("paramsValue $paramsValue");
    mirrorLog.info("paramType $paramType");

    return paramType;
  }
}
