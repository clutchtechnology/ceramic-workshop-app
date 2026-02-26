import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/top_bar/dt_health_status.dart';
import '../providers/admin_provider.dart';
import 'realtime_dashboard_page.dart';
import 'data_history_page.dart';
import 'settings_page.dart';
import 'sensor_status_page.dart';
import 'alarm_records_page.dart';

/// 顶部导航栏目
class DigitalTwinPage extends StatefulWidget {
  const DigitalTwinPage({super.key});

  @override
  State<DigitalTwinPage> createState() => _DigitalTwinPageState();
}

class _DigitalTwinPageState extends State<DigitalTwinPage> with WindowListener {
  // ============================================================
  // 状态变量
  // ============================================================

  // 1, 当前选中的导航索引 (0=实时大屏, 1=历史数据, 2=报警记录, 3=状态监控, 4=系统配置)
  int _selectedNavIndex = 0;

  // 2, 时钟定时器（替代 Stream.periodic 防止内存泄漏）
  Timer? _clockTimer;
  String _timeString = '';

  // 8, 窗口状态（是否全屏/最大化）
  bool _restoreFullScreenAfterMinimize = false;

  // [CRITICAL] 防止 onWindowRestore + onWindowFocus 同时触发 setFullScreen 竞态
  bool _isRestoringFullScreen = false;

  // [CRITICAL] 本地追踪全屏状态，避免 FutureBuilder 异步延迟
  // 初始值 = true，与 main.dart 中 setFullScreen(true) 一致
  bool _isCurrentlyFullScreen = true;

  // [CRITICAL] 防止全屏切换按钮连击导致多条异步链交叉执行
  bool _isTogglingFullScreen = false;

  // ============================================================
  // 页面 GlobalKey (用于调用子页面方法)
  // ============================================================

  // 3, 历史数据页面 Key
  final GlobalKey<HistoryDataPageState> _historyDataPageKey =
      GlobalKey<HistoryDataPageState>();

  // 4, 实时大屏页面 Key
  final GlobalKey<RealtimeDashboardPageState> _realtimeDashboardPageKey =
      GlobalKey<RealtimeDashboardPageState>();

  // 5, 状态监控页面 Key
  final GlobalKey<SensorStatusPageState> _sensorStatusPageKey =
      GlobalKey<SensorStatusPageState>();

  // 6, 报警记录页面 Key
  final GlobalKey<AlarmRecordsPageState> _alarmRecordsPageKey =
      GlobalKey<AlarmRecordsPageState>();

  // ============================================================
  // 页面实例缓存 (保持页面状态)
  // 注意: SettingsPage 不缓存，每次进入都重新构建，避免 Provider 依赖问题
  // ============================================================
  late final Widget _realtimeDashboardPage;
  late final Widget _historyDataPage;
  late final Widget _sensorStatusPage;
  late final Widget _alarmRecordsPage;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 初始化页面实例 (SettingsPage 不缓存，动态构建)
    _realtimeDashboardPage =
        RealtimeDashboardPage(key: _realtimeDashboardPageKey);
    _historyDataPage = HistoryDataPage(key: _historyDataPageKey);
    _sensorStatusPage = SensorStatusPage(key: _sensorStatusPageKey);
    _alarmRecordsPage = AlarmRecordsPage(key: _alarmRecordsPageKey);

    // 2, 启动时钟定时器
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });

    //  [CRITICAL] 确保非活跃页面的 Timer 不运行
    // 延迟执行，等待页面完成构建后再控制 Timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 默认显示实时大屏 (index=0)，确保其他页面的 Timer 已暂停
      _pausePagePolling(2); // 暂停报警记录页
      _pausePagePolling(3); // 暂停状态监控页
      // 只有当前页面 (index=0) 的 Timer 应该运行
    });
  }

  /// 2, 更新时钟显示
  void _updateTime() {
    final now = DateTime.now();
    final newTimeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    if (_timeString != newTimeString) {
      setState(() => _timeString = newTimeString);
    }
  }

  @override
  void dispose() {
    // 2, [CRITICAL] 取消时钟定时器，防止内存泄漏
    _clockTimer?.cancel();
    _clockTimer = null;

    //  确保所有子页面的 Timer 都被取消
    _pausePagePolling(0);
    _pausePagePolling(2);
    _pausePagePolling(3);

    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    if (!mounted) return;
    _isCurrentlyFullScreen = true;
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) return;
    _isCurrentlyFullScreen = false;
  }

  @override
  void onWindowMinimize() {
    // [CRITICAL] 窗口最小化时记录全屏状态，恢复时使用
    if (!mounted) return;
    if (_isCurrentlyFullScreen) {
      _restoreFullScreenAfterMinimize = true;
    }
  }

  @override
  void onWindowRestore() {
    if (!mounted) return;
    _tryRestoreFullScreenAfterMinimize();
  }

  @override
  void onWindowFocus() {
    if (!mounted) return;
    _tryRestoreFullScreenAfterMinimize();
  }

  /// [CRITICAL] 从最小化恢复全屏，带竞态保护和延迟等待
  /// onWindowRestore 和 onWindowFocus 可能在极短时间内同时触发
  /// 必须用 _isRestoringFullScreen 防止重入
  Future<void> _tryRestoreFullScreenAfterMinimize() async {
    // 1. 检查前置条件
    if (!_restoreFullScreenAfterMinimize || !mounted) return;
    // 2. 防止重入（onWindowRestore + onWindowFocus 几乎同时触发）
    if (_isRestoringFullScreen) return;
    _isRestoringFullScreen = true;
    _restoreFullScreenAfterMinimize = false;

    try {
      // 3. 延迟 300ms 等待窗口恢复到正常尺寸
      //    Windows 从最小化恢复时需要时间重新布局
      //    如果立即 setFullScreen(true)，Flutter 可能在零尺寸窗口上渲染 -> 崩溃
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      // [CRITICAL] 延迟期间窗口可能被再次最小化，必须检查
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        // 窗口仍在最小化状态，下次恢复时重试
        _restoreFullScreenAfterMinimize = true;
        return;
      }
      await windowManager.setFullScreen(true);
    } catch (e) {
      // 忽略窗口操作异常（窗口可能已关闭）
    } finally {
      _isRestoringFullScreen = false;
    }
  }

  /// 统一页面切换逻辑
  void _switchToPage(int index) {
    final previousIndex = _selectedNavIndex;
    if (previousIndex == index) return;

    setState(() => _selectedNavIndex = index);

    //  暂停离开页面的定时器
    _pausePagePolling(previousIndex);

    //  恢复/初始化进入页面的定时器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumePagePolling(index);
    });
  }

  /// 导航项点击处理
  /// 1, 切换页面并管理各页面的定时器状态
  void _onNavItemTap(int index) {
    _switchToPage(index);
  }

  /// 暂停指定页面的轮询
  void _pausePagePolling(int pageIndex) {
    switch (pageIndex) {
      case 0: // 实时大屏
        _realtimeDashboardPageKey.currentState?.pausePolling();
        break;
      case 2: // 报警记录
        _alarmRecordsPageKey.currentState?.pausePolling();
        break;
      case 3: // 状态监控
        _sensorStatusPageKey.currentState?.pausePolling();
        break;
    }
  }

  /// 恢复指定页面的轮询
  void _resumePagePolling(int pageIndex) {
    switch (pageIndex) {
      case 0: // 实时大屏
        _realtimeDashboardPageKey.currentState?.resumePolling();
        break;
      case 1: // 历史数据
        _historyDataPageKey.currentState?.onPageEnter();
        break;
      case 2: // 报警记录
        _alarmRecordsPageKey.currentState?.resumePolling();
        break;
      case 3: // 状态监控
        _sensorStatusPageKey.currentState?.resumePolling();
        break;
    }
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
  /// 使用 Offstage + TickerMode 替代 IndexedStack
  /// 避免 Consumer 在隐藏页面中的依赖问题
  Widget _buildSelectedView() {
    return Stack(
      children: [
        // 实时大屏
        Offstage(
          offstage: _selectedNavIndex != 0,
          child: TickerMode(
            enabled: _selectedNavIndex == 0,
            child: _realtimeDashboardPage,
          ),
        ),
        // 历史数据
        Offstage(
          offstage: _selectedNavIndex != 1,
          child: TickerMode(
            enabled: _selectedNavIndex == 1,
            child: _historyDataPage,
          ),
        ),
        // 报警记录
        Offstage(
          offstage: _selectedNavIndex != 2,
          child: TickerMode(
            enabled: _selectedNavIndex == 2,
            child: _alarmRecordsPage,
          ),
        ),
        // 状态监控
        Offstage(
          offstage: _selectedNavIndex != 3,
          child: TickerMode(
            enabled: _selectedNavIndex == 3,
            child: _sensorStatusPage,
          ),
        ),
        //  系统配置 - 每次都重新构建，不缓存
        // 使用 Builder 确保在正确的 context 中构建
        if (_selectedNavIndex == 4)
          Builder(builder: (context) => const SettingsPage()),
      ],
    );
  }

  /// 顶部导航栏
  Widget _buildTopNavBar() {
    final navItems = ['实时大屏', '历史数据', '报警记录', '状态监控'];

    return GestureDetector(
      // 1. 让 top_bar 可以拖动窗口
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
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
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _onNavItemTap(index),
                  behavior: HitTestBehavior.opaque, // 确保透明区域也能响应点击
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
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
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            // 时间显示
            _buildClockDisplay(),
            const SizedBox(width: 12),
            // 设置按钮
            GestureDetector(
              onTap: () => _showPasswordDialog(),
              behavior: HitTestBehavior.opaque, // 增大点击判定区域
              child: Container(
                padding: const EdgeInsets.all(12), // 增大内边距
                decoration: BoxDecoration(
                  color: _selectedNavIndex == 4
                      ? TechColors.glowCyan.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.settings,
                  color: _selectedNavIndex == 4
                      ? TechColors.glowCyan
                      : TechColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 8, 窗口控制按钮（最小化/最大化/关闭）
            _buildWindowControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildClockDisplay() {
    return Row(
      children: [
        // 刷新数据按钮（仅在实时大屏页面显示）
        if (_selectedNavIndex == 0) ...[
          _buildRefreshButton(),
          const SizedBox(width: 12),
        ],
        const HealthStatusWidget(),
        const SizedBox(width: 12),
        //  使用 Timer + setState 替代 StreamBuilder，防止内存泄漏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: TechColors.bgMedium,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: TechColors.glowCyan.withOpacity(0.3),
            ),
          ),
          child: Text(
            _timeString,
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
        ),
      ],
    );
  }

  // ============================================================
  // 8, 窗口控制按钮
  // ============================================================

  /// 构建窗口控制按钮（最小化、最大化/还原、关闭）
  Widget _buildWindowControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 最小化按钮
        _buildWindowButton(
          icon: Icons.remove,
          tooltip: '最小化',
          onTap: () async {
            try {
              // [CRITICAL] 直接最小化，不退出全屏，避免原生标题栏闪烁
              await windowManager.minimize();
            } catch (e) {
              // [FALLBACK] 部分 Windows 环境下全屏无法直接最小化
              try {
                _restoreFullScreenAfterMinimize = _isCurrentlyFullScreen;
                await windowManager.setFullScreen(false);
                await windowManager.minimize();
              } catch (_) {}
            }
          },
        ),
        const SizedBox(width: 4),
        // 2. 最大化/还原按钮（使用本地状态，避免 FutureBuilder 异步闪烁）
        _buildWindowButton(
          icon:
              _isCurrentlyFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
          tooltip: _isCurrentlyFullScreen ? '退出全屏' : '全屏',
          onTap: () async {
            // [CRITICAL] 防止连击导致多条异步链交叉执行
            if (_isTogglingFullScreen) return;
            _isTogglingFullScreen = true;
            try {
              if (_isCurrentlyFullScreen) {
                // 退出全屏 -> 最大化窗口（保持隐藏标题栏）
                await windowManager.setFullScreen(false);
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                // [CRITICAL] 退出全屏后重新隐藏原生标题栏
                await windowManager.setTitleBarStyle(
                  TitleBarStyle.hidden,
                  windowButtonVisibility: false,
                );
                await windowManager.setResizable(false);
                await windowManager.maximize();
              } else {
                // 进入全屏
                await windowManager.setFullScreen(true);
              }
              if (mounted) setState(() {});
            } catch (e) {
              // 窗口操作异常不应导致应用崩溃
            } finally {
              _isTogglingFullScreen = false;
            }
          },
        ),
        const SizedBox(width: 4),
        // 关闭按钮
        _buildWindowButton(
          icon: Icons.close,
          tooltip: '关闭',
          isClose: true,
          onTap: () async {
            await windowManager.close();
          },
        ),
      ],
    );
  }

  /// 构建单个窗口控制按钮（移除 Tooltip 避免 IndexedStack 布局问题）
  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip, // 保留参数但不使用 Tooltip
    required VoidCallback onTap,
    bool isClose = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      hoverColor: isClose
          ? Colors.red.withOpacity(0.8)
          : TechColors.glowCyan.withOpacity(0.2),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isClose ? Colors.red.shade300 : TechColors.textSecondary,
        ),
      ),
    );
  }

  /// 构建刷新按钮
  Widget _buildRefreshButton() {
    final isRefreshing =
        _realtimeDashboardPageKey.currentState?.isRefreshing ?? false;

    return InkWell(
      onTap: isRefreshing
          ? null
          : () {
              _realtimeDashboardPageKey.currentState?.refreshData();
              // 触发UI更新
              setState(() {});
            },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isRefreshing
              ? TechColors.bgMedium
              : TechColors.glowOrange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isRefreshing
                ? TechColors.borderDark
                : TechColors.glowOrange.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRefreshing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    TechColors.glowOrange,
                  ),
                ),
              )
            else
              Icon(
                Icons.refresh,
                size: 16,
                color: TechColors.glowOrange,
              ),
            const SizedBox(width: 6),
            Text(
              isRefreshing ? '刷新中...' : '刷新数据',
              style: TextStyle(
                color: isRefreshing
                    ? TechColors.textSecondary
                    : TechColors.glowOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto Mono',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示密码验证对话框
  Future<void> _showPasswordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _AdminPasswordDialog(),
    );

    //  [CRITICAL] showDialog 的 Future 会在 pop 时立刻完成，但弹窗退出动画仍在进行。
    // 这里延迟一小段时间，避免在弹窗退场过程中触发页面重建引发 InheritedElement 销毁断言。
    if (result == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _switchToPage(4);
      }
    }
  }
}

class _AdminPasswordDialog extends StatefulWidget {
  const _AdminPasswordDialog();

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _verify() {
    final adminProvider = context.read<AdminProvider>();
    final password = _passwordController.text;

    if (adminProvider.authenticate('admin', password)) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('密码错误'),
        backgroundColor: TechColors.statusAlarm,
        duration: const Duration(seconds: 2),
      ),
    );
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _passwordController,
              obscureText: !_showPassword,
              autofocus: true,
              onSubmitted: (_) => _verify(),
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
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: TechColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
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
                    Navigator.of(context).pop(false);
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
                  onPressed: _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TechColors.glowCyan.withOpacity(0.2),
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
  }
}
