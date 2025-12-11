import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/top_bar.dart';
import 'providers/realtime_config_provider.dart';
import 'providers/admin_provider.dart';

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

  // 创建并初始化 Provider
  final realtimeConfigProvider = RealtimeConfigProvider();
  await realtimeConfigProvider.loadConfig();

  final adminProvider = AdminProvider();
  await adminProvider.initialize();

  runApp(MyApp(
    realtimeConfigProvider: realtimeConfigProvider,
    adminProvider: adminProvider,
  ));
}

class MyApp extends StatelessWidget {
  final RealtimeConfigProvider realtimeConfigProvider;
  final AdminProvider adminProvider;

  const MyApp({
    super.key,
    required this.realtimeConfigProvider,
    required this.adminProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: realtimeConfigProvider),
        ChangeNotifierProvider.value(value: adminProvider),
      ],
      child: MaterialApp(
        title: 'Ceramic Workshop Digital Twin',
        theme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const DigitalTwinPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
