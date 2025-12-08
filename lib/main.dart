import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/digital_twin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器 - 隐藏原生标题栏，使用自定义标题栏
  // TODO: 临时设置为21寸16:9固定窗口 (1536x864)，后续恢复为全屏
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // 21寸16:9比例 ≈ 1536x864 (相对于27寸1920x1080)
    const fixedSize = Size(1536, 864);

    WindowOptions windowOptions = const WindowOptions(
      size: fixedSize,
      minimumSize: fixedSize, // 固定最小尺寸
      maximumSize: fixedSize, // 固定最大尺寸，禁止放大
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏原生标题栏
      windowButtonVisibility: false, // 隐藏原生窗口按钮
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(false); // 禁止调整大小
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能生产线数字孪生系统',
      theme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const DigitalTwinPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
