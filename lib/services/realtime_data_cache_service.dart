import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/hopper_model.dart';
import '../models/roller_kiln_model.dart';
import '../models/scr_fan_model.dart';
import '../utils/app_logger.dart';

/// 实时数据缓存服务
/// 用于持久化存储最后一次成功获取的实时数据，App 重启后可恢复显示
///
/// 🔧 性能优化:
/// - 节流机制: 最小30秒写入间隔，避免频繁I/O
/// - 防并发: 使用标志位防止并发写入冲突
class RealtimeDataCacheService {
  static final RealtimeDataCacheService _instance =
      RealtimeDataCacheService._internal();
  factory RealtimeDataCacheService() => _instance;
  RealtimeDataCacheService._internal();

  static const String _cacheFileName = 'realtime_data_cache.json';
  File? _cacheFile;

  // 🔧 节流控制: 最小写入间隔30秒
  DateTime? _lastSaveTime;
  static const Duration _minSaveInterval = Duration(seconds: 30);
  bool _isSaving = false; // 防止并发写入

  /// 初始化缓存文件路径
  Future<void> _ensureCacheFile() async {
    if (_cacheFile != null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${directory.path}/ceramic_workshop');
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      _cacheFile = File('${dataDir.path}/$_cacheFileName');
      logger.info('缓存文件路径: ${_cacheFile!.path}');
    } catch (e, stack) {
      logger.error('初始化缓存文件失败', e, stack);
    }
  }

  /// 保存缓存数据
  /// 🔧 节流优化: 最小30秒间隔，防止频繁I/O导致卡顿
  Future<void> saveCache({
    required Map<String, HopperData> hopperData,
    RollerKilnData? rollerKilnData,
    ScrFanBatchData? scrFanData,
  }) async {
    // 🔧 节流检查: 距上次保存不足30秒则跳过
    final now = DateTime.now();
    if (_lastSaveTime != null &&
        now.difference(_lastSaveTime!) < _minSaveInterval) {
      return; // 静默跳过，不记录日志
    }

    // 🔧 防并发: 正在保存则跳过
    if (_isSaving) return;

    try {
      _isSaving = true;
      await _ensureCacheFile();
      if (_cacheFile == null) return;

      final cacheData = {
        'timestamp': now.toIso8601String(),
        'hopper': hopperData.map((k, v) => MapEntry(k, v.toJson())),
        'roller_kiln': rollerKilnData?.toJson(),
        'scr_fan': scrFanData?.toJson(),
      };

      await _cacheFile!.writeAsString(jsonEncode(cacheData));
      _lastSaveTime = now; // 记录本次保存时间
    } catch (e, stack) {
      logger.error('保存缓存数据失败', e, stack);
    } finally {
      _isSaving = false;
    }
  }

  /// 加载缓存数据
  Future<CachedRealtimeData?> loadCache() async {
    try {
      await _ensureCacheFile();
      if (_cacheFile == null) return null;

      if (!await _cacheFile!.exists()) {
        logger.info('缓存文件不存在，将使用空数据');
        return null;
      }

      final content = await _cacheFile!.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 解析 hopper 数据
      final hopperJson = json['hopper'] as Map<String, dynamic>? ?? {};
      final hopperData = hopperJson.map(
        (k, v) => MapEntry(k, HopperData.fromJson(v as Map<String, dynamic>)),
      );

      // 解析 roller_kiln 数据
      RollerKilnData? rollerKilnData;
      if (json['roller_kiln'] != null) {
        rollerKilnData = RollerKilnData.fromJson(
            json['roller_kiln'] as Map<String, dynamic>);
      }

      // 解析 scr_fan 数据
      ScrFanBatchData? scrFanData;
      if (json['scr_fan'] != null) {
        scrFanData =
            ScrFanBatchData.fromJson(json['scr_fan'] as Map<String, dynamic>);
      }

      final timestamp = json['timestamp'] as String?;
      logger.info('已加载缓存数据 (缓存时间: $timestamp, hopper=${hopperData.length}个设备)');

      return CachedRealtimeData(
        hopperData: hopperData,
        rollerKilnData: rollerKilnData,
        scrFanData: scrFanData,
        cachedAt: timestamp != null ? DateTime.tryParse(timestamp) : null,
      );
    } catch (e, stack) {
      logger.error('加载缓存数据失败', e, stack);
      return null;
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      await _ensureCacheFile();
      if (_cacheFile != null && await _cacheFile!.exists()) {
        await _cacheFile!.delete();
        logger.info('缓存已清除');
      }
    } catch (e, stack) {
      logger.error('清除缓存失败', e, stack);
    }
  }
}

/// 缓存的实时数据
class CachedRealtimeData {
  final Map<String, HopperData> hopperData;
  final RollerKilnData? rollerKilnData;
  final ScrFanBatchData? scrFanData;
  final DateTime? cachedAt;

  CachedRealtimeData({
    required this.hopperData,
    this.rollerKilnData,
    this.scrFanData,
    this.cachedAt,
  });

  /// 是否有有效数据
  bool get hasData =>
      hopperData.isNotEmpty || rollerKilnData != null || scrFanData != null;
}
