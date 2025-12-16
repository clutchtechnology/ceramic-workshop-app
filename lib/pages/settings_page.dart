import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/settings/realtime_data_settings_widget.dart';
import '../providers/backend_config_provider.dart';
import '../providers/admin_provider.dart';

/// 系统配置页
/// 支持配置服务器、PLC等参数
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedSection = 0; // 0: 服务配置, 1: PLC配置, 2: 实时数据设置, 3: 管理员设置

  final BackendConfigProvider _configProvider = BackendConfigProvider();

  // PLC配置表单控制器
  final _plcIpController = TextEditingController();
  final _plcPollIntervalController = TextEditingController();

  bool _isTestingConnection = false;
  String? _connectionTestResult;
  bool? _connectionTestSuccess;

  @override
  void initState() {
    super.initState();
    _initializeConfig();
  }

  Future<void> _initializeConfig() async {
    await _configProvider.initialize();
    _updatePlcControllers();
    if (mounted) setState(() {});
  }

  void _updatePlcControllers() {
    if (_configProvider.plcConfig != null) {
      _plcIpController.text = _configProvider.plcConfig!.ipAddress;
      _plcPollIntervalController.text =
          _configProvider.plcConfig!.pollInterval.toString();
    }
  }

  @override
  void dispose() {
    _plcIpController.dispose();
    _plcPollIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TechColors.bgDeep,
      child: AnimatedGridBackground(
        gridColor: TechColors.borderDark.withOpacity(0.3),
        gridSize: 40,
        child: Row(
          children: [
            // 左侧导航菜单
            _buildNavigationMenu(),
            // 右侧配置内容
            Expanded(
              child: _buildConfigContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// 左侧导航菜单
  Widget _buildNavigationMenu() {
    final sections = [
      {'icon': Icons.dns, 'label': '服务配置'},
      {'icon': Icons.settings_input_component, 'label': 'PLC 配置'},
      {'icon': Icons.dashboard_customize, 'label': '实时数据设置'},
      {'icon': Icons.security, 'label': '管理员设置'},
    ];

    return Container(
      width: 220,
      margin: const EdgeInsets.all(12),
      child: TechPanel(
        title: '配置菜单',
        accentColor: TechColors.glowCyan,
        child: Column(
          children: [
            // 菜单项列表
            ...List.generate(sections.length, (index) {
              final section = sections[index];
              final isSelected = _selectedSection == index;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSection = index;
                        _connectionTestResult = null;
                        _connectionTestSuccess = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TechColors.glowCyan.withOpacity(0.15)
                            : TechColors.bgMedium.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? TechColors.glowCyan.withOpacity(0.5)
                              : TechColors.borderDark,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            section['icon'] as IconData,
                            size: 20,
                            color: isSelected
                                ? TechColors.glowCyan
                                : TechColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section['label'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? TechColors.glowCyan
                                    : TechColors.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: TechColors.glowCyan,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            // 弹性空间
            const Spacer(),
            // 分隔线
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 1,
              color: TechColors.borderDark,
            ),
            // 窗口控制按钮
            _buildWindowControlButtons(),
          ],
        ),
      ),
    );
  }

  /// 窗口控制按钮（退出程序）
  Widget _buildWindowControlButtons() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // 显示确认对话框
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: TechColors.bgDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: TechColors.statusAlarm.withOpacity(0.5),
                ),
              ),
              title: const Text(
                '确认关闭',
                style: TextStyle(color: TechColors.textPrimary),
              ),
              content: const Text(
                '确定要关闭应用程序吗？',
                style: TextStyle(color: TechColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: TechColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TechColors.statusAlarm.withOpacity(0.2),
                    foregroundColor: TechColors.statusAlarm,
                  ),
                  child: const Text('确认关闭'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await windowManager.close();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TechColors.statusAlarm.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: TechColors.statusAlarm.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.close,
                size: 20,
                color: TechColors.statusAlarm,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '退出程序',
                  style: TextStyle(
                    color: TechColors.statusAlarm,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧配置内容区域
  Widget _buildConfigContent() {
    // 实时数据设置页面使用独立的布局
    if (_selectedSection == 2) {
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        child: TechPanel(
          title: '实时数据阈值与颜色配置',
          accentColor: TechColors.glowOrange,
          child: const RealtimeDataSettingsWidget(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      child: TechPanel(
        title: _getSectionTitle(),
        accentColor: TechColors.glowCyan,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionContent(),
            ],
          ),
        ),
      ),
    );
  }

  String _getSectionTitle() {
    switch (_selectedSection) {
      case 0:
        return '服务配置 (只读)';
      case 1:
        return 'PLC 配置';
      case 2:
        return '实时数据阈值与颜色配置';
      case 3:
        return '管理员设置';
      default:
        return '系统配置';
    }
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 0:
        return _buildServerConfig();
      case 1:
        return _buildPLCConfig();
      case 3:
        return _buildAdminSettings();
      default:
        return const SizedBox();
    }
  }

  // ============================================================================
  // 服务配置 (只读)
  // ============================================================================

  Widget _buildServerConfig() {
    if (_configProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(TechColors.glowCyan),
        ),
      );
    }

    if (_configProvider.error != null && _configProvider.serverConfig == null) {
      return _buildErrorWidget(_configProvider.error!);
    }

    final serverConfig = _configProvider.serverConfig;
    if (serverConfig == null) {
      return _buildErrorWidget('无法获取服务配置');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          title: '后端服务信息',
          icon: Icons.dns,
          children: [
            _buildInfoRow('主机地址', serverConfig.host, Icons.computer),
            _buildInfoRow(
                '端口号', serverConfig.port.toString(), Icons.settings_ethernet),
            _buildInfoRow(
                '调试模式', serverConfig.debug ? '开启' : '关闭', Icons.bug_report),
          ],
        ),
        const SizedBox(height: 16),
        // 刷新按钮
        OutlinedButton.icon(
          onPressed: () async {
            await _configProvider.refreshFromBackend();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('刷新配置'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TechColors.glowCyan,
            side: BorderSide(color: TechColors.glowCyan.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // PLC 配置
  // ============================================================================

  Widget _buildPLCConfig() {
    if (_configProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(TechColors.glowCyan),
        ),
      );
    }

    if (_configProvider.error != null && _configProvider.plcConfig == null) {
      return _buildErrorWidget(_configProvider.error!);
    }

    final plcConfig = _configProvider.plcConfig;
    if (plcConfig == null) {
      return _buildErrorWidget('无法获取PLC配置');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 只读信息
        _buildInfoCard(
          title: 'PLC 连接信息 (只读)',
          icon: Icons.info_outline,
          children: [
            _buildInfoRow('Rack', plcConfig.rack.toString(), Icons.view_module),
            _buildInfoRow('Slot', plcConfig.slot.toString(), Icons.memory),
            _buildInfoRow('超时时间', '${plcConfig.timeoutMs} ms', Icons.timer),
            _buildInfoRow('轮询间隔', '${plcConfig.pollInterval} 秒', Icons.update),
          ],
        ),
        const SizedBox(height: 24),

        // 可编辑字段
        const Text(
          '可编辑配置',
          style: TextStyle(
            color: TechColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        _buildConfigField(
          label: 'PLC IP 地址',
          controller: _plcIpController,
          icon: Icons.router,
          hint: '例: 192.168.50.223',
        ),
        const SizedBox(height: 24),

        // 操作按钮
        _buildPlcActionButtons(),

        // 连接测试结果
        if (_connectionTestResult != null) ...[
          const SizedBox(height: 16),
          _buildConnectionTestResult(),
        ],
      ],
    );
  }

  Widget _buildPlcActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _savePlcConfig,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存配置'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TechColors.glowCyan.withOpacity(0.2),
            foregroundColor: TechColors.glowCyan,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: TechColors.glowCyan.withOpacity(0.5)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isTestingConnection ? null : _testPlcConnection,
          icon: _isTestingConnection
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(TechColors.glowGreen),
                  ),
                )
              : const Icon(Icons.wifi_tethering, size: 18),
          label: Text(_isTestingConnection ? '测试中...' : '测试连接'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TechColors.glowGreen.withOpacity(0.2),
            foregroundColor: TechColors.glowGreen,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: TechColors.glowGreen.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 通用组件
  // ============================================================================

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: TechColors.glowCyan),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: TechColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: TechColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(
              color: TechColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: TechColors.textPrimary,
              fontSize: 13,
              fontFamily: 'Roboto Mono',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TechColors.statusAlarm.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TechColors.statusAlarm.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: TechColors.statusAlarm, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(color: TechColors.statusAlarm, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () async {
              await _configProvider.refreshFromBackend();
              if (mounted) setState(() {});
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: TechColors.statusAlarm,
              side: BorderSide(color: TechColors.statusAlarm.withOpacity(0.5)),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: TechColors.glowCyan),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: TechColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters:
              isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: const TextStyle(
            color: TechColors.textPrimary,
            fontSize: 13,
            fontFamily: 'Roboto Mono',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: TechColors.textMuted,
              fontSize: 12,
            ),
            filled: true,
            fillColor: TechColors.bgMedium,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: TechColors.glowCyan.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: TechColors.glowCyan.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: TechColors.glowCyan,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 管理员设置
  // ============================================================================

  Widget _buildAdminSettings() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              title: '账号信息',
              icon: Icons.account_circle,
              children: [
                _buildInfoRow('用户名', adminProvider.adminConfig?.username ?? '-',
                    Icons.person),
              ],
            ),
            const SizedBox(height: 24),
            _buildChangePasswordSection(adminProvider),
          ],
        );
      },
    );
  }

  Widget _buildChangePasswordSection(AdminProvider adminProvider) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '修改密码',
              style: TextStyle(
                color: TechColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildPasswordField(
              label: '旧密码',
              controller: oldPasswordController,
              showPassword: showOldPassword,
              onVisibilityToggle: () {
                setState(() => showOldPassword = !showOldPassword);
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              label: '新密码',
              controller: newPasswordController,
              showPassword: showNewPassword,
              onVisibilityToggle: () {
                setState(() => showNewPassword = !showNewPassword);
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              label: '确认新密码',
              controller: confirmPasswordController,
              showPassword: showConfirmPassword,
              onVisibilityToggle: () {
                setState(() => showConfirmPassword = !showConfirmPassword);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final oldPassword = oldPasswordController.text;
                    final newPassword = newPasswordController.text;
                    final confirmPassword = confirmPasswordController.text;

                    // 验证输入
                    if (oldPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('请输入旧密码'),
                          backgroundColor: TechColors.statusAlarm,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    if (newPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('请输入新密码'),
                          backgroundColor: TechColors.statusAlarm,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    if (newPassword != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('两次输入的新密码不一致'),
                          backgroundColor: TechColors.statusAlarm,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    if (newPassword.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('新密码长度至少6位'),
                          backgroundColor: TechColors.statusAlarm,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // 修改密码
                    final success = await adminProvider.updatePassword(
                      oldPassword,
                      newPassword,
                    );

                    if (!mounted) return;

                    if (success) {
                      oldPasswordController.clear();
                      newPasswordController.clear();
                      confirmPasswordController.clear();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('密码修改成功'),
                          backgroundColor: TechColors.glowGreen,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            adminProvider.error ?? '密码修改失败',
                          ),
                          backgroundColor: TechColors.statusAlarm,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('确认修改'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TechColors.glowCyan.withOpacity(0.2),
                    foregroundColor: TechColors.glowCyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: TechColors.glowCyan.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    oldPasswordController.clear();
                    newPasswordController.clear();
                    confirmPasswordController.clear();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TechColors.textSecondary,
                    side: const BorderSide(color: TechColors.borderDark),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool showPassword,
    required VoidCallback onVisibilityToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock, size: 16, color: TechColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: TechColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !showPassword,
          style: const TextStyle(
            color: TechColors.textPrimary,
            fontSize: 13,
            fontFamily: 'Roboto Mono',
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: TechColors.bgDeep,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: TechColors.borderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: TechColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: TechColors.glowCyan),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility : Icons.visibility_off,
                color: TechColors.textSecondary,
                size: 18,
              ),
              onPressed: onVisibilityToggle,
            ),
            hintText: '输入 $label',
            hintStyle: TextStyle(
              color: TechColors.textSecondary.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionTestResult() {
    final isSuccess = _connectionTestSuccess == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isSuccess ? TechColors.glowGreen : TechColors.statusAlarm)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (isSuccess ? TechColors.glowGreen : TechColors.statusAlarm)
              .withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? TechColors.glowGreen : TechColors.statusAlarm,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _connectionTestResult ?? '',
              style: TextStyle(
                color:
                    isSuccess ? TechColors.glowGreen : TechColors.statusAlarm,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 操作方法
  // ============================================================================

  Future<void> _savePlcConfig() async {
    final newConfig = PlcConfigData(
      ipAddress: _plcIpController.text,
      rack: _configProvider.plcConfig?.rack ?? 0,
      slot: _configProvider.plcConfig?.slot ?? 1,
      timeoutMs: _configProvider.plcConfig?.timeoutMs ?? 5000,
      pollInterval: int.tryParse(_plcPollIntervalController.text) ?? 5,
    );

    final success = await _configProvider.updatePlcConfig(newConfig);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? TechColors.glowGreen : TechColors.statusAlarm,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              success ? 'PLC配置保存成功！' : '配置保存失败: ${_configProvider.error}',
              style: const TextStyle(color: TechColors.textPrimary),
            ),
          ],
        ),
        backgroundColor: TechColors.bgMedium,
        duration: const Duration(seconds: 2),
      ),
    );

    if (success) {
      _updatePlcControllers();
      setState(() {});
    }
  }

  Future<void> _testPlcConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
      _connectionTestSuccess = null;
    });

    final result = await _configProvider.testPlcConnection();

    if (!mounted) return;

    setState(() {
      _isTestingConnection = false;
      _connectionTestSuccess = result['connected'] == true;
      _connectionTestResult = result['message'] as String?;
    });
  }
}
