import "package:ccviewer_mobile_hub/main.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("renders app shell with ConnectionListPage", (tester) async {
    await tester.pumpWidget(const CcViewerMobileApp());
    await tester.pumpAndSettle();

    // 首页标题改为 CCTV
    expect(find.text("CCTV"), findsOneWidget);
    // 右上角应该是菜单入口
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text("扫码连接"), findsOneWidget);
    expect(find.text("定时任务"), findsOneWidget);
    expect(find.text("个人设置"), findsOneWidget);
  });
}
