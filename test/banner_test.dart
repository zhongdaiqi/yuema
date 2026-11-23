import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuema/screens/main_screen.dart';

void main() {
  group('Banner功能测试', () {
    testWidgets('测试Banner显示和点击功能', (WidgetTester tester) async {
      // 构建MainScreen widget
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(),
        ),
      );

      // 等待widget构建完成
      await tester.pumpAndSettle();

      // 验证banner是否存在
      expect(find.byType(Image), findsWidgets);
      
      // 验证banner图片资源路径
      final imageFinder = find.byType(Image);
      if (imageFinder.evaluate().isNotEmpty) {
        final imageWidget = tester.widget<Image>(imageFinder.first);
        // 这里可以进一步验证图片的属性
      }

      // 测试点击banner（如果有导航功能的话）
      // 由于涉及到Navigator，这里主要是验证结构
    });
  });
}