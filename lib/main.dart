import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/top_bar.dart';
import 'providers/realtime_config_provider.dart';
import 'providers/admin_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器 - 全屏显示，隐藏原生标题栏
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏原生标题栏
      windowButtonVisibility: false, // 隐藏原生窗口按钮
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setFullScreen(true); // 全屏显示
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
      child: GestureDetector(
        // 点击空白处时取消焦点，隐藏键盘
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: MaterialApp(
          title: 'Ceramic Workshop Digital Twin',
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const DigitalTwinPage(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
