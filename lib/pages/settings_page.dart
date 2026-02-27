import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/data_display/data_tech_line_widgets.dart';
import '../widgets/settings/realtime_data_settings_widget.dart';
import '../providers/admin_provider.dart';

/// 系统配置页
/// 支持配置服务器、PLC等参数
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ============================================================
  // 状态变量
  // ============================================================

  // 1, 当前选中的配置区块索引 (0:服务, 1:PLC, 2:实时数据, 3:管理员)
  int _selectedSection = 0;

  // 2, 密码修改输入控制器 (提升到类级别，避免每次build重建)
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ============================================================
  // 生命周期
  // ============================================================

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
        return 'PLC 配置 (只读)';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          title: '后端服务',
          icon: Icons.dns,
          children: [
            _buildInfoRow('主机地址', '0.0.0.0', Icons.computer),
            _buildInfoRow('端口号', '8080', Icons.settings_ethernet),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'InfluxDB',
          icon: Icons.storage,
          children: [
            _buildInfoRow('地址', 'http://localhost:8086', Icons.link),
            _buildInfoRow('组织', 'clutchtech', Icons.business),
            _buildInfoRow('Bucket', 'sensor_data', Icons.inbox),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // PLC 配置 (只读)
  // ============================================================================

  Widget _buildPLCConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          title: 'PLC 连接参数',
          icon: Icons.settings_input_component,
          children: [
            _buildInfoRow('IP 地址', '192.168.50.223', Icons.router),
            _buildInfoRow('Rack', '0', Icons.view_module),
            _buildInfoRow('Slot', '1', Icons.memory),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: '轮询配置',
          icon: Icons.update,
          children: [
            _buildInfoRow('实时数据间隔', '5 秒', Icons.speed),
            _buildInfoRow('状态位间隔', '5 秒', Icons.monitor_heart),
            _buildInfoRow('批量写入批次', '10 次', Icons.batch_prediction),
          ],
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

  // ============================================================================
  // 管理员设置
  // ============================================================================

  Widget _buildAdminSettings() {
    //  [CRITICAL] 使用 context.watch 替代 Consumer
    // 避免在页面切换时 '_dependents.isEmpty' 错误
    final AdminProvider adminProvider;
    try {
      adminProvider = context.watch<AdminProvider>();
    } catch (e) {
      // Provider 未就绪时显示加载状态
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(TechColors.glowCyan),
        ),
      );
    }

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
  }

  Widget _buildChangePasswordSection(AdminProvider adminProvider) {
    // 5, 使用类级别的密码控制器 (已在 dispose 中释放)
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
              controller: _oldPasswordController,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              label: '新密码',
              controller: _newPasswordController,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              label: '确认新密码',
              controller: _confirmPasswordController,
            ),
            const SizedBox(height: 24),
            _buildPasswordActionButtons(adminProvider),
          ],
        );
      },
    );
  }

  /// 密码操作按钮
  Widget _buildPasswordActionButtons(AdminProvider adminProvider) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _handleChangePassword(adminProvider),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('确认修改'),
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
        OutlinedButton.icon(
          onPressed: _clearPasswordFields,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重置'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TechColors.textSecondary,
            side: const BorderSide(color: TechColors.borderDark),
          ),
        ),
      ],
    );
  }

  /// 处理密码修改
  Future<void> _handleChangePassword(AdminProvider adminProvider) async {
    // 5, 获取密码输入值
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 验证输入
    if (oldPassword.isEmpty) {
      _showSnackBar('请输入旧密码', isError: true);
      return;
    }
    if (newPassword.isEmpty) {
      _showSnackBar('请输入新密码', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('两次输入的新密码不一致', isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar('新密码长度至少6位', isError: true);
      return;
    }

    // 修改密码
    final success =
        await adminProvider.updatePassword(oldPassword, newPassword);
    if (!mounted) return;

    if (success) {
      _clearPasswordFields();
      _showSnackBar('密码修改成功', isError: false);
    } else {
      _showSnackBar(adminProvider.error ?? '密码修改失败', isError: true);
    }
  }

  /// 清空密码输入框
  void _clearPasswordFields() {
    // 5, 清空密码控制器
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  /// 显示 SnackBar 消息
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? TechColors.statusAlarm : TechColors.glowGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
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
          obscureText: true,
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
            hintText: '输入 $label',
            hintStyle: TextStyle(
              color: TechColors.textSecondary.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }
}
