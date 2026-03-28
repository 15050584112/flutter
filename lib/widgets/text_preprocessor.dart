/// 文本预处理器
/// 用于处理消息中的工具调用标记和格式化 Markdown 文本
class TextPreprocessor {
  /// 预处理消息文本，返回处理后的 Markdown 字符串和提取出的工具调用列表
  static PreprocessResult process(String rawText) {
    String text = rawText;
    final List<String> tools = [];

    // 1. 提取工具调用标记
    final toolRegex = RegExp(r'\[tool:(\w+)\]');
    for (final match in toolRegex.allMatches(text)) {
      tools.add(match.group(1)!);
    }
    text = text.replaceAll(toolRegex, '').trim();

    // 2. 清理多余空行（超过 2 个连续空行合并为 2 个）
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 3. 修复不规范的代码块（确保 ``` 前后有空行）
    text = text.replaceAllMapped(
      RegExp(r'([^\n])\n```'),
      (m) => '${m.group(1)}\n\n```',
    );

    return PreprocessResult(markdown: text, tools: tools);
  }
}

/// 预处理结果
class PreprocessResult {
  final String markdown;
  final List<String> tools;

  const PreprocessResult({required this.markdown, required this.tools});
}
