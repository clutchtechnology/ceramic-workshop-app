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

  // 1, 当前选中的导航索引 (0=实时大屏, 1=历史数据, 2=状态监控, 3=报警记录, 4=系统配置)
  int _selectedNavIndex = 0;

  // 2, 时钟定时器（替代 Stream.periodic 防止内存泄漏）
  Timer? _clockTimer;
  String _timeString = '';

  // 8, 窗口状态（是否全屏/最大化）
  bool _restoreFullScreenAfterMinimize = false;

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
      _pausePagePolling(2); // 暂停状态监控页
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

    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    if (!mounted) return;
    // _isFullScreen 未被使用，移除赋值以消除警告
    // setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) return;
    // _isFullScreen 未被使用，移除赋值以消除警告
    // setState(() => _isFullScreen = false);
  }

  @override
  void onWindowRestore() {
    _tryRestoreFullScreenAfterMinimize();
  }

  @override
  void onWindowFocus() {
    _tryRestoreFullScreenAfterMinimize();
  }

  Future<void> _tryRestoreFullScreenAfterMinimize() async {
    if (!_restoreFullScreenAfterMinimize || !mounted) return;
    _restoreFullScreenAfterMinimize = false;
    try {
      await windowManager.setFullScreen(true);
    } catch (_) {
      // ignore
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
      case 0: // 4, 实时大屏
        _realtimeDashboardPageKey.currentState?.pausePolling();
        break;
      case 2: // 5, 状态监控
        _sensorStatusPageKey.currentState?.pausePolling();
        break;
      case 3: // 6, 报警记录
        _alarmRecordsPageKey.currentState?.pausePolling();
        break;
    }
  }

  /// 恢复指定页面的轮询
  void _resumePagePolling(int pageIndex) {
    switch (pageIndex) {
      case 0: // 4, 实时大屏
        _realtimeDashboardPageKey.currentState?.resumePolling();
        break;
      case 1: // 3, 历史数据
        _historyDataPageKey.currentState?.onPageEnter();
        break;
      case 2: // 5, 状态监控
        _sensorStatusPageKey.currentState?.resumePolling();
        break;
      case 3: // 6, 报警记录
        _alarmRecordsPageKey.currentState?.resumePolling();
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
        // 状态监控
        Offstage(
          offstage: _selectedNavIndex != 2,
          child: TickerMode(
            enabled: _selectedNavIndex == 2,
            child: _sensorStatusPage,
          ),
        ),
        // 报警记录
        Offstage(
          offstage: _selectedNavIndex != 3,
          child: TickerMode(
            enabled: _selectedNavIndex == 3,
            child: _alarmRecordsPage,
          ),
        ),
        // 系统配置 - 每次都重新构建，不缓存
        if (_selectedNavIndex == 4)
          Builder(builder: (context) => const SettingsPage()),
      ],
    );
  }

  /// 顶部导航栏
  Widget _buildTopNavBar() {
    final navItems = ['实时大屏', '历史数据', '状态监控', '报警记录'];

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
          const SizedBox(width: 12),
          // 导航项
          ...List.generate(navItems.length, (index) {
            final isSelected = _selectedNavIndex == index;
            return Container(
              margin: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => _onNavItemTap(index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(width: 20),
          // 设置按钮
          GestureDetector(
            onTap: () => _showPasswordDialog(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(10),
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
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 8, 窗口控制按钮（最小化/还原/关闭）
          _buildWindowControls(),
        ],
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

  /// 构建窗口控制按钮（最小化、关闭）
  Widget _buildWindowControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 最小化按钮
        _buildWindowButton(
          icon: Icons.remove,
          tooltip: '最小化',
          onTap: () async {
            // Windows 下全屏窗口可能无法直接最小化：先退出全屏再最小化
            final isFullScreen = await windowManager.isFullScreen();
            if (isFullScreen) {
              _restoreFullScreenAfterMinimize = true;
              await windowManager.setFullScreen(false);
            }
            await windowManager.minimize();
          },
        ),
        const SizedBox(width: 4),
        // 关闭按钮
        _buildWindowButton(
          icon: Icons.close,
          tooltip: '关闭',
          isClose: true,
          onTap: () => _showCloseConfirmDialog(),
        ),
      ],
    );
  }

  /// 构建单个窗口控制按钮（移除 Tooltip 避免 IndexedStack 布局问题）

  /// 显示关闭确认弹窗
  Future<void> _showCloseConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: TechColors.bgMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: TechColors.statusAlarm.withOpacity(0.5)),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TechColors.bgMedium,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: TechColors.statusAlarm.withOpacity(0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: TechColors.statusAlarm,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '确认关闭',
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
                '确定要关闭应用程序吗？',
                style: TextStyle(
                  color: TechColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TechColors.textSecondary,
                      side: BorderSide(color: TechColors.borderDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TechColors.statusAlarm.withOpacity(0.2),
                      foregroundColor: TechColors.statusAlarm,
                      side: BorderSide(
                        color: TechColors.statusAlarm.withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    child: const Text('确认关闭'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await windowManager.close();
    }
  }

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
