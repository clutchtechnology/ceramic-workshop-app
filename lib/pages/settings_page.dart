import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/config_models.dart';
import '../widgets/tech_line_widgets.dart';
import '../services/config_service.dart';

/// 系统配置页
/// 支持配置服务器、PLC、数据库、传感器等参数
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SystemConfig _systemConfig;
  int _selectedSection = 0; // 0: 服务器, 1: PLC, 2: 数据库, 3: 传感器

  final _configService = ConfigService();

  // 表单控制器
  final _serverIpController = TextEditingController();
  final _serverPortController = TextEditingController();
  final _plcIpController = TextEditingController();
  final _plcPortController = TextEditingController();
  final _plcRackController = TextEditingController();
  final _plcSlotController = TextEditingController();
  final _dbHostController = TextEditingController();
  final _dbPortController = TextEditingController();
  final _dbUserController = TextEditingController();
  final _dbPasswordController = TextEditingController();
  final _dbNameController = TextEditingController();

  bool _isTestingConnection = false;
  String? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() async {
    // 从持久化存储加载配置
    final savedConfig = await _configService.loadConfig();

    setState(() {
      _systemConfig = savedConfig ??
          SystemConfig(
            sensors: _getDefaultSensors(),
          );
      _updateControllers();
    });
  }

  void _updateControllers() {
    _serverIpController.text = _systemConfig.serverConfig.ipAddress;
    _serverPortController.text = _systemConfig.serverConfig.port.toString();
    _plcIpController.text = _systemConfig.plcConfig.ipAddress;
    _plcPortController.text = _systemConfig.plcConfig.port.toString();
    _plcRackController.text = _systemConfig.plcConfig.rack.toString();
    _plcSlotController.text = _systemConfig.plcConfig.slot.toString();
    _dbHostController.text = _systemConfig.databaseConfig.host;
    _dbPortController.text = _systemConfig.databaseConfig.port.toString();
    _dbUserController.text = _systemConfig.databaseConfig.username;
    _dbPasswordController.text = _systemConfig.databaseConfig.password;
    _dbNameController.text = _systemConfig.databaseConfig.databaseName;
  }

  List<SensorConfig> _getDefaultSensors() {
    return [
      SensorConfig(
        id: 'TEMP_ZONE_1',
        name: '温区1温度传感器',
        type: 'temperature',
        modbusAddress: 100,
        dataPoint: 0,
        unit: '℃',
      ),
      SensorConfig(
        id: 'TEMP_ZONE_2',
        name: '温区2温度传感器',
        type: 'temperature',
        modbusAddress: 101,
        dataPoint: 0,
        unit: '℃',
      ),
      SensorConfig(
        id: 'FLOW_METER_1',
        name: '气体流量计1',
        type: 'flow',
        modbusAddress: 200,
        dataPoint: 0,
        unit: 'm³/h',
      ),
      SensorConfig(
        id: 'PRESSURE_1',
        name: '压力传感器1',
        type: 'pressure',
        modbusAddress: 300,
        dataPoint: 0,
        unit: 'Pa',
      ),
    ];
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _serverPortController.dispose();
    _plcIpController.dispose();
    _plcPortController.dispose();
    _plcRackController.dispose();
    _plcSlotController.dispose();
    _dbHostController.dispose();
    _dbPortController.dispose();
    _dbUserController.dispose();
    _dbPasswordController.dispose();
    _dbNameController.dispose();
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
      {'icon': Icons.dns, 'label': '服务器配置'},
      {'icon': Icons.settings_input_component, 'label': 'PLC 配置'},
      {'icon': Icons.storage, 'label': '数据库配置'},
      {'icon': Icons.sensors, 'label': '传感器配置'},
    ];

    return Container(
      width: 220,
      margin: const EdgeInsets.all(12),
      child: TechPanel(
        title: '配置菜单',
        accentColor: TechColors.glowCyan,
        child: Column(
          children: List.generate(sections.length, (index) {
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
        ),
      ),
    );
  }

  /// 右侧配置内容区域
  Widget _buildConfigContent() {
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
              const SizedBox(height: 24),
              _buildActionButtons(),
              if (_connectionTestResult != null) ...[
                const SizedBox(height: 16),
                _buildConnectionTestResult(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getSectionTitle() {
    switch (_selectedSection) {
      case 0:
        return '服务器地址配置';
      case 1:
        return 'PLC 地址配置';
      case 2:
        return '数据库地址配置';
      case 3:
        return '传感器地址配置';
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
      case 2:
        return _buildDatabaseConfig();
      case 3:
        return _buildSensorConfig();
      default:
        return const SizedBox();
    }
  }

  /// 服务器配置表单
  Widget _buildServerConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigField(
          label: 'IP 地址',
          controller: _serverIpController,
          icon: Icons.language,
          hint: '例: 192.168.1.100',
        ),
        const SizedBox(height: 16),
        _buildConfigField(
          label: '端口号',
          controller: _serverPortController,
          icon: Icons.settings_ethernet,
          hint: '例: 8080',
          isNumber: true,
        ),
      ],
    );
  }

  /// PLC 配置表单
  Widget _buildPLCConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigField(
          label: 'IP 地址',
          controller: _plcIpController,
          icon: Icons.router,
          hint: '例: 192.168.0.1',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildConfigField(
                label: '端口号',
                controller: _plcPortController,
                icon: Icons.settings_input_hdmi,
                hint: '102',
                isNumber: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildConfigField(
                label: 'Rack',
                controller: _plcRackController,
                icon: Icons.view_module,
                hint: '0',
                isNumber: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildConfigField(
                label: 'Slot',
                controller: _plcSlotController,
                icon: Icons.memory,
                hint: '1',
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildProtocolSelector(),
      ],
    );
  }

  Widget _buildProtocolSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.settings_input_component,
              size: 16,
              color: TechColors.glowCyan,
            ),
            const SizedBox(width: 8),
            const Text(
              '通信协议',
              style: TextStyle(
                color: TechColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TechColors.bgMedium,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: TechColors.glowCyan.withOpacity(0.3),
            ),
          ),
          child: DropdownButton<String>(
            value: _systemConfig.plcConfig.protocol,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: TechColors.bgMedium,
            style: const TextStyle(
              color: TechColors.textPrimary,
              fontSize: 13,
              fontFamily: 'Roboto Mono',
            ),
            items: ['S7-1200', 'S7-1500', 'S7-300', 'S7-400']
                .map((protocol) => DropdownMenuItem(
                      value: protocol,
                      child: Text(protocol),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _systemConfig.plcConfig.protocol = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  /// 数据库配置表单
  Widget _buildDatabaseConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigField(
          label: '主机地址',
          controller: _dbHostController,
          icon: Icons.computer,
          hint: 'localhost 或 IP 地址',
        ),
        const SizedBox(height: 16),
        _buildConfigField(
          label: '端口号',
          controller: _dbPortController,
          icon: Icons.settings_ethernet,
          hint: '3306',
          isNumber: true,
        ),
        const SizedBox(height: 16),
        _buildConfigField(
          label: '数据库名称',
          controller: _dbNameController,
          icon: Icons.storage,
          hint: 'ceramic_workshop',
        ),
        const SizedBox(height: 16),
        _buildConfigField(
          label: '用户名',
          controller: _dbUserController,
          icon: Icons.person,
          hint: 'root',
        ),
        const SizedBox(height: 16),
        _buildConfigField(
          label: '密码',
          controller: _dbPasswordController,
          icon: Icons.lock,
          hint: '••••••',
          isPassword: true,
        ),
      ],
    );
  }

  /// 传感器配置表单
  Widget _buildSensorConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '传感器列表',
              style: TextStyle(
                color: TechColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addNewSensor,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加传感器'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TechColors.glowCyan.withOpacity(0.2),
                foregroundColor: TechColors.glowCyan,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._systemConfig.sensors.asMap().entries.map((entry) {
          final index = entry.key;
          final sensor = entry.value;
          return _buildSensorItem(sensor, index);
        }),
      ],
    );
  }

  Widget _buildSensorItem(SensorConfig sensor, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TechColors.bgMedium.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: sensor.enabled
              ? TechColors.glowCyan.withOpacity(0.3)
              : TechColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getSensorIcon(sensor.type),
                          size: 16,
                          color: sensor.enabled
                              ? TechColors.glowCyan
                              : TechColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sensor.name,
                          style: TextStyle(
                            color: sensor.enabled
                                ? TechColors.textPrimary
                                : TechColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${sensor.id}',
                      style: const TextStyle(
                        color: TechColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Roboto Mono',
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: sensor.enabled,
                onChanged: (value) {
                  setState(() {
                    _systemConfig.sensors[index].enabled = value;
                  });
                },
                activeColor: TechColors.glowCyan,
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: TechColors.glowCyan,
                onPressed: () => _editSensor(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                color: TechColors.statusAlarm,
                onPressed: () => _deleteSensor(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TechColors.bgDeep.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                _buildSensorDetail('Modbus', '${sensor.modbusAddress}'),
                const SizedBox(width: 16),
                _buildSensorDetail('数据点', '${sensor.dataPoint}'),
                const SizedBox(width: 16),
                _buildSensorDetail('单位', sensor.unit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDetail(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: TechColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: TechColors.glowCyan,
            fontSize: 11,
            fontFamily: 'Roboto Mono',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getSensorIcon(String type) {
    switch (type) {
      case 'temperature':
        return Icons.thermostat;
      case 'pressure':
        return Icons.speed;
      case 'flow':
        return Icons.water;
      default:
        return Icons.sensors;
    }
  }

  /// 通用配置字段
  Widget _buildConfigField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isNumber = false,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: TechColors.glowCyan,
            ),
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
          obscureText: isPassword,
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

  /// 操作按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saveConfig,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存配置'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TechColors.glowCyan.withOpacity(0.2),
            foregroundColor: TechColors.glowCyan,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(
                color: TechColors.glowCyan.withOpacity(0.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isTestingConnection ? null : _testConnection,
          icon: _isTestingConnection
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(TechColors.glowCyan),
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
              side: BorderSide(
                color: TechColors.glowGreen.withOpacity(0.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _resetConfig,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重置'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TechColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            side: BorderSide(
              color: TechColors.borderDark,
            ),
          ),
        ),
      ],
    );
  }

  /// 连接测试结果
  Widget _buildConnectionTestResult() {
    final isSuccess = _connectionTestResult == 'success';
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
              isSuccess ? '连接测试成功！' : '连接测试失败，请检查配置参数。',
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

  void _saveConfig() async {
    // 更新配置对象
    _systemConfig.serverConfig.ipAddress = _serverIpController.text;
    _systemConfig.serverConfig.port =
        int.tryParse(_serverPortController.text) ?? 8080;
    _systemConfig.plcConfig.ipAddress = _plcIpController.text;
    _systemConfig.plcConfig.port = int.tryParse(_plcPortController.text) ?? 102;
    _systemConfig.plcConfig.rack = int.tryParse(_plcRackController.text) ?? 0;
    _systemConfig.plcConfig.slot = int.tryParse(_plcSlotController.text) ?? 1;
    _systemConfig.databaseConfig.host = _dbHostController.text;
    _systemConfig.databaseConfig.port =
        int.tryParse(_dbPortController.text) ?? 3306;
    _systemConfig.databaseConfig.username = _dbUserController.text;
    _systemConfig.databaseConfig.password = _dbPasswordController.text;
    _systemConfig.databaseConfig.databaseName = _dbNameController.text;

    // 持久化保存配置到本地存储
    final success = await _configService.saveConfig(_systemConfig);

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
              success ? '配置保存成功！' : '配置保存失败，请重试',
              style: const TextStyle(color: TechColors.textPrimary),
            ),
          ],
        ),
        backgroundColor: TechColors.bgMedium,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });

    // TODO: 实现实际的连接测试逻辑
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isTestingConnection = false;
      // 模拟测试结果
      _connectionTestResult =
          DateTime.now().second % 2 == 0 ? 'success' : 'failed';
    });
  }

  void _resetConfig() {
    setState(() {
      _loadConfig();
      _connectionTestResult = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info, color: TechColors.glowCyan, size: 20),
            SizedBox(width: 12),
            Text('配置已重置为默认值', style: TextStyle(color: TechColors.textPrimary)),
          ],
        ),
        backgroundColor: TechColors.bgMedium,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addNewSensor() {
    showDialog(
      context: context,
      builder: (context) => _SensorEditDialog(
        onSave: (sensor) {
          setState(() {
            _systemConfig.sensors.add(sensor);
          });
        },
      ),
    );
  }

  void _editSensor(int index) {
    showDialog(
      context: context,
      builder: (context) => _SensorEditDialog(
        sensor: _systemConfig.sensors[index],
        onSave: (sensor) {
          setState(() {
            _systemConfig.sensors[index] = sensor;
          });
        },
      ),
    );
  }

  void _deleteSensor(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TechColors.bgMedium,
        title: const Text(
          '删除传感器',
          style: TextStyle(color: TechColors.textPrimary),
        ),
        content: Text(
          '确定要删除传感器 "${_systemConfig.sensors[index].name}" 吗？',
          style: const TextStyle(color: TechColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消',
                style: TextStyle(color: TechColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _systemConfig.sensors.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('删除',
                style: TextStyle(color: TechColors.statusAlarm)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 传感器编辑对话框
// ============================================================================

class _SensorEditDialog extends StatefulWidget {
  final SensorConfig? sensor;
  final Function(SensorConfig) onSave;

  const _SensorEditDialog({
    this.sensor,
    required this.onSave,
  });

  @override
  State<_SensorEditDialog> createState() => _SensorEditDialogState();
}

class _SensorEditDialogState extends State<_SensorEditDialog> {
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _modbusController;
  late TextEditingController _dataPointController;
  late TextEditingController _unitController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    final sensor = widget.sensor;
    _idController = TextEditingController(text: sensor?.id ?? '');
    _nameController = TextEditingController(text: sensor?.name ?? '');
    _modbusController =
        TextEditingController(text: sensor?.modbusAddress.toString() ?? '0');
    _dataPointController =
        TextEditingController(text: sensor?.dataPoint.toString() ?? '0');
    _unitController = TextEditingController(text: sensor?.unit ?? '℃');
    _selectedType = sensor?.type ?? 'temperature';
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _modbusController.dispose();
    _dataPointController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TechColors.bgMedium,
      title: Text(
        widget.sensor == null ? '添加传感器' : '编辑传感器',
        style: const TextStyle(color: TechColors.textPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField('传感器ID', _idController, Icons.fingerprint),
              const SizedBox(height: 12),
              _buildDialogField('传感器名称', _nameController, Icons.label),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              const SizedBox(height: 12),
              _buildDialogField(
                  'Modbus地址', _modbusController, Icons.location_on,
                  isNumber: true),
              const SizedBox(height: 12),
              _buildDialogField('数据点', _dataPointController, Icons.scatter_plot,
                  isNumber: true),
              const SizedBox(height: 12),
              _buildDialogField('单位', _unitController, Icons.straighten),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消',
              style: TextStyle(color: TechColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: TechColors.glowCyan.withOpacity(0.2),
            foregroundColor: TechColors.glowCyan,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(color: TechColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TechColors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: TechColors.glowCyan),
        filled: true,
        fillColor: TechColors.bgDeep,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: TechColors.glowCyan.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      dropdownColor: TechColors.bgDeep,
      style: const TextStyle(color: TechColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: '传感器类型',
        labelStyle: const TextStyle(color: TechColors.textSecondary),
        prefixIcon:
            const Icon(Icons.category, size: 18, color: TechColors.glowCyan),
        filled: true,
        fillColor: TechColors.bgDeep,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: TechColors.glowCyan.withOpacity(0.3)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'temperature', child: Text('温度传感器')),
        DropdownMenuItem(value: 'pressure', child: Text('压力传感器')),
        DropdownMenuItem(value: 'flow', child: Text('流量传感器')),
        DropdownMenuItem(value: 'other', child: Text('其他')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedType = value);
        }
      },
    );
  }

  void _save() {
    final sensor = SensorConfig(
      id: _idController.text,
      name: _nameController.text,
      type: _selectedType,
      modbusAddress: int.tryParse(_modbusController.text) ?? 0,
      dataPoint: int.tryParse(_dataPointController.text) ?? 0,
      unit: _unitController.text,
      enabled: widget.sensor?.enabled ?? true,
    );

    widget.onSave(sensor);
    Navigator.pop(context);
  }
}
