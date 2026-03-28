import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 工具调用标签行
class ToolBadgeRow extends StatelessWidget {
  final List<String> tools;

  const ToolBadgeRow({super.key, required this.tools});

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: tools.map((name) => _ToolBadge(name: name)).toList(),
      ),
    );
  }
}

/// 单个工具标签
class _ToolBadge extends StatelessWidget {
  final String name;

  const _ToolBadge({required this.name});

  IconData get _icon {
    switch (name) {
      case 'bash':
        return Icons.terminal;
      case 'write':
      case 'edit':
        return Icons.edit_note;
      case 'read':
        return Icons.description_outlined;
      case 'search':
      case 'grep':
        return Icons.search;
      case 'browser':
        return Icons.language;
      default:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.toolBadgeHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.toolBadgePaddingH,
      ),
      decoration: BoxDecoration(
        color: AppColors.toolBadgeBg,
        borderRadius: BorderRadius.circular(AppDimensions.toolBadgeRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: AppDimensions.toolBadgeIconSize,
            color: AppColors.toolBadgeIcon,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.toolBadgeText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
