import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'code_block_widget.dart';

/// Markdown 渲染组件
/// 使用 flutter_markdown 并配置自定义样式
class MarkdownRenderer extends StatelessWidget {
  final String markdown;

  const MarkdownRenderer({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: markdown,
      selectable: true,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: _buildStyleSheet(context),
      builders: {
        'code': CodeBlockBuilder(),
      },
      onTapLink: (text, href, title) {
        if (href != null) launchUrl(Uri.parse(href));
      },
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      // 段落
      p: AppTextStyles.assistantBodyText,
      pPadding: const EdgeInsets.only(bottom: 8),

      // 标题
      h1: AppTextStyles.assistantH1,
      h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h2: AppTextStyles.assistantH2,
      h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h3: AppTextStyles.assistantH3,
      h3Padding: const EdgeInsets.only(top: 8, bottom: 4),

      // 行内代码
      code: GoogleFonts.jetBrainsMono(
        fontSize: 13.5,
        color: AppColors.inlineCodeText,
        backgroundColor: AppColors.inlineCodeBg,
      ),
      codeblockDecoration: const BoxDecoration(),

      // 引用块
      blockquote: TextStyle(
        fontSize: 14,
        color: AppColors.blockquoteText,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.blockquoteBg,
        border: Border(
          left: BorderSide(
            color: AppColors.blockquoteBorder,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),

      // 列表
      listBullet: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
      listIndent: 20.0,

      // 表格
      tableHead: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      tableBorder: TableBorder.all(color: Color(0xFFE2E8F0), width: 1),
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      // 水平分割线
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),

      // 加粗和斜体
      strong: const TextStyle(fontWeight: FontWeight.w700),
      em: const TextStyle(fontStyle: FontStyle.italic),

      // 链接
      a: const TextStyle(
        color: Color(0xFF2563EB),
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFF93C5FD),
      ),
    );
  }
}
