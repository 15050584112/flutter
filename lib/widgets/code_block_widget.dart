import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// flutter_markdown 的自定义代码块 Builder
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = '';
    String code = element.textContent;

    if (element.attributes['class'] != null) {
      language = element.attributes['class']!.replaceFirst('language-', '');
    }

    return CodeBlockWidget(code: code, language: language);
  }
}

/// 代码块展示组件
class CodeBlockWidget extends StatelessWidget {
  final String code;
  final String language;

  const CodeBlockWidget({
    super.key,
    required this.code,
    this.language = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: AppDimensions.codeBlockMarginV),
      decoration: BoxDecoration(
        color: AppColors.codeBlockBg,
        borderRadius: BorderRadius.circular(AppDimensions.codeBlockRadius),
        border: Border.all(color: AppColors.codeBlockBorder, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CodeHeader(language: language, code: code),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AppDimensions.codeBlockMaxHeight,
            ),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.codeBlockPaddingH,
                    12,
                    AppDimensions.codeBlockPaddingH,
                    AppDimensions.codeBlockPaddingV,
                  ),
                  child: SyntaxHighlightedCode(
                    code: code,
                    language: language,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 代码块头部（语言标签 + 复制按钮）
class _CodeHeader extends StatefulWidget {
  final String language;
  final String code;

  const _CodeHeader({required this.language, required this.code});

  @override
  State<_CodeHeader> createState() => _CodeHeaderState();
}

class _CodeHeaderState extends State<_CodeHeader> {
  bool _copied = false;

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.codeBlockHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.codeBlockHeaderBg,
      child: Row(
        children: [
          if (widget.language.isNotEmpty)
            Text(
              widget.language,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.codeBlockHeaderText,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _copyCode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 14,
                  color: _copied
                      ? AppColors.syntaxString
                      : AppColors.codeBlockHeaderText,
                ),
                const SizedBox(width: 4),
                Text(
                  _copied ? 'Copied!' : 'Copy',
                  style: TextStyle(
                    fontSize: 12,
                    color: _copied
                        ? AppColors.syntaxString
                        : AppColors.codeBlockHeaderText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 基于正则的轻量语法高亮
class SyntaxHighlightedCode extends StatelessWidget {
  final String code;
  final String language;

  const SyntaxHighlightedCode({
    super.key,
    required this.code,
    this.language = '',
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          height: 1.5,
          color: AppColors.codeBlockText,
        ),
        children: _highlight(code, language),
      ),
    );
  }

  List<TextSpan> _highlight(String code, String lang) {
    final rules = <_HighlightRule>[
      // 1. 多行注释
      _HighlightRule(RegExp(r'/\*[\s\S]*?\*/'), AppColors.syntaxComment),
      // 2. 单行注释
      _HighlightRule(
          RegExp(r'(?://|#).*$', multiLine: true), AppColors.syntaxComment),
      // 3. 字符串
      _HighlightRule(
        RegExp(r'"""[\s\S]*?"""|'
            "'''[\\s\\S]*?'''|"
            r'"(?:[^"\\]|\\.)*"|'
            "'(?:[^'\\\\]|\\\\.)*'"),
        AppColors.syntaxString,
      ),
      // 4. 关键字
      _HighlightRule(
        RegExp(r'\b(?:import|export|from|class|extends|implements|interface|enum|'
            r'function|def|fn|func|const|let|var|final|static|async|await|'
            r'return|yield|if|else|for|while|do|switch|case|break|continue|'
            r'try|catch|finally|throw|new|this|self|super|null|nil|true|false|'
            r'void|int|double|float|bool|String|List|Map|Set|Future|Stream|'
            r'public|private|protected|abstract|override|package|type|struct)\b'),
        AppColors.syntaxKeyword,
      ),
      // 5. 数字
      _HighlightRule(
        RegExp(r'\b\d+\.?\d*(?:e[+-]?\d+)?\b', caseSensitive: false),
        AppColors.syntaxNumber,
      ),
      // 6. 函数调用
      _HighlightRule(
          RegExp(r'\b([a-zA-Z_]\w*)(?=\()'), AppColors.syntaxFunction),
      // 7. 类型名
      _HighlightRule(RegExp(r'\b[A-Z][a-zA-Z0-9]*\b'), AppColors.syntaxType),
      // 8. 运算符
      _HighlightRule(
          RegExp(r'[+\-*/=<>!&|^~%?:]+'), AppColors.syntaxOperator),
    ];

    final matches = <_Match>[];
    for (final rule in rules) {
      for (final m in rule.pattern.allMatches(code)) {
        matches.add(_Match(m.start, m.end, rule.color));
      }
    }

    matches.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.end.compareTo(a.end);
    });

    final spans = <TextSpan>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start < cursor) continue;
      if (m.start > cursor) {
        spans.add(TextSpan(text: code.substring(cursor, m.start)));
      }
      spans.add(TextSpan(
        text: code.substring(m.start, m.end),
        style: TextStyle(color: m.color),
      ));
      cursor = m.end;
    }
    if (cursor < code.length) {
      spans.add(TextSpan(text: code.substring(cursor)));
    }

    return spans;
  }
}

class _HighlightRule {
  final RegExp pattern;
  final Color color;

  const _HighlightRule(this.pattern, this.color);
}

class _Match {
  final int start;
  final int end;
  final Color color;

  const _Match(this.start, this.end, this.color);
}
