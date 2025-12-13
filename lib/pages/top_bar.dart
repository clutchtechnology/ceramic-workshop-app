import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/top_bar/dt_health_status.dart';
import '../providers/admin_provider.dart';
import 'realtime_dashboard_page.dart';
import 'data_display_page.dart';
import 'settings_page.dart';

/// 顶部导航栏目
class DigitalTwinPage extends StatefulWidget {
  const DigitalTwinPage({super.key});

  @override
  State<DigitalTwinPage> createState() => _DigitalTwinPageState();
}

class _DigitalTwinPageState extends State<DigitalTwinPage> {
  int _selectedNavIndex = 0;

  // 页面实例缓存 - 保持页面状态
  late final Widget _realtimeDashboardPage = const RealtimeDashboardPage();
  late final Widget _dataDisplayPage = const DataDisplayPage();
  late final Widget _settingsPage = const SettingsPage();

  @override
  void initState() {
    super.initState();
    // TODO: 接入PLC数据后，在此处初始化数据连接
  }

  @override
  void dispose() {
    // TODO: 接入PLC数据后，在此处释放数据连接
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechColors.bgDeep,
      body: AnimatedGridBackground(
        gridColor: TechColors.borderDark.withOpacity(0.3),
        gridSize: 40,
        child: Column(
          children: [
            // 顶部导航栏
            _buildTopNavBar(),
            // 主内容区 - 根据选择的Tab显示不同页面
            Expanded(
              child: _buildSelectedView(),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据选中的导航项构建对应视图
  Widget _buildSelectedView() {
    // 使用 IndexedStack 保持所有页面的状态
    return IndexedStack(
      index: _selectedNavIndex,
      children: [
        _realtimeDashboardPage, // 实时大屏
        _dataDisplayPage, // 数据展示
        _settingsPage, // 系统配置
      ],
    );
  }

  /// 顶部导航栏
  Widget _buildTopNavBar() {
    final navItems = ['实时大屏', '数据展示'];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: TechColors.bgDark.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: TechColors.glowCyan.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo/标题
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: TechColors.glowCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: TechColors.glowCyan.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [TechColors.glowCyan, TechColors.glowCyanLight],
                ).createShader(bounds),
                child: const Text(
                  '英格瓷磨料车间',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          // 导航项
          ...List.generate(navItems.length, (index) {
            final isSelected = _selectedNavIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedNavIndex = index),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TechColors.glowCyan.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? TechColors.glowCyan.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  navItems[index],
                  style: TextStyle(
                    color: isSelected
                        ? TechColors.glowCyan
                        : TechColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // 时间显示
          _buildClockDisplay(),
          const SizedBox(width: 20),
          // 设置按钮
          GestureDetector(
            onTap: () => _showPasswordDialog(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedNavIndex == 2
                    ? TechColors.glowCyan.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.settings,
                color: _selectedNavIndex == 2
                    ? TechColors.glowCyan
                    : TechColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockDisplay() {
    return Row(
      children: [
        const HealthStatusWidget(),
        const SizedBox(width: 12),
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: TechColors.bgMedium,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: TechColors.glowCyan.withOpacity(0.3),
                ),
              ),
              child: Text(
                timeStr,
                style: TextStyle(
                  color: TechColors.glowCyan,
                  fontSize: 14,
                  fontFamily: 'Roboto Mono',
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: TechColors.glowCyan.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 显示密码验证对话框
  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool showPassword = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: TechColors.bgMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: TechColors.glowCyan.withOpacity(0.5),
                ),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TechColors.bgMedium,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: TechColors.glowCyan.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lock,
                          color: TechColors.glowCyan,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '管理员验证',
                          style: TextStyle(
                            color: TechColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '请输入管理员密码:',
                      style: TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: !showPassword,
                      autofocus: true,
                      style: const TextStyle(
                        color: TechColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: TechColors.bgDeep,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: TechColors.borderDark,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: TechColors.borderDark,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: TechColors.glowCyan,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: TechColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                        hintText: '输入密码',
                        hintStyle: TextStyle(
                          color: TechColors.textSecondary.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            passwordController.dispose();
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TechColors.textSecondary,
                            side: BorderSide(
                              color: TechColors.borderDark,
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final adminProvider = context.read<AdminProvider>();
                            final password = passwordController.text;

                            if (adminProvider.authenticate('admin', password)) {
                              Navigator.of(context).pop(true); // 返回 true 表示验证成功
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('密码错误'),
                                  backgroundColor: TechColors.statusAlarm,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              passwordController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                TechColors.glowCyan.withOpacity(0.2),
                            foregroundColor: TechColors.glowCyan,
                            side: BorderSide(
                              color: TechColors.glowCyan.withOpacity(0.5),
                            ),
                          ),
                          child: const Text('确认'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      passwordController.dispose();
      // 验证成功后切换到设置页面
      if (result == true) {
        setState(() => _selectedNavIndex = 2);
      }
    });
  }
}
