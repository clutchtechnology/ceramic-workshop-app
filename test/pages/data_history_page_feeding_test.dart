/// 投料验证与回填逻辑的单元测试
///
/// 测试目标：
/// 1. Rising Edge 检测算法
/// 2. 防抖机制
/// 3. 记录匹配逻辑
/// 4. 回填触发条件

import 'package:flutter_test/flutter_test.dart';
import 'package:ceramic_workshop_app/services/history_data_service.dart';

void main() {
  group('投料验证与回填逻辑测试', () {
    // 测试辅助方法 - 模拟 HistoryDataPoint
    HistoryDataPoint createWeightPoint(DateTime time, double weight) {
      return HistoryDataPoint(
        time: time,
        fields: {'weight': weight},
      );
    }

    // 测试辅助方法 - 模拟 FeedingRecord
    FeedingRecord createFeedingRecord(DateTime time, double weight) {
      return FeedingRecord(
        time: time,
        addedWeight: weight,
        deviceId: 'test_hopper',
      );
    }

    test('应该检测到单个投料事件（重量增加 > 10kg）', () {
      // 模拟数据：t0=100kg, t1=115kg (增加15kg)
      final points = [
        createWeightPoint(DateTime(2026, 1, 18, 10, 0), 100.0),
        createWeightPoint(DateTime(2026, 1, 18, 10, 5), 115.0),
      ];

      // 计算重量差
      final diff = _calculateWeightDiff(points[0], points[1]);

      expect(diff, 15.0);
      expect(diff > 10.0, true, reason: '应该触发投料检测');
    });

    test('不应该检测到小幅波动（重量增加 < 10kg）', () {
      // 模拟数据：t0=100kg, t1=108kg (增加8kg)
      final points = [
        createWeightPoint(DateTime(2026, 1, 18, 10, 0), 100.0),
        createWeightPoint(DateTime(2026, 1, 18, 10, 5), 108.0),
      ];

      final diff = _calculateWeightDiff(points[0], points[1]);

      expect(diff, 8.0);
      expect(diff > 10.0, false, reason: '不应触发投料检测');
    });

    test('应该忽略重量下降', () {
      // 模拟数据：t0=115kg, t1=100kg (下降15kg，可能是卸料)
      final points = [
        createWeightPoint(DateTime(2026, 1, 18, 10, 0), 115.0),
        createWeightPoint(DateTime(2026, 1, 18, 10, 5), 100.0),
      ];

      final diff = _calculateWeightDiff(points[0], points[1]);

      expect(diff, -15.0);
      expect(diff > 10.0, false, reason: '下降不应触发投料检测');
    });

    test('防抖机制：应该忽略30分钟内的重复触发', () {
      final time1 = DateTime(2026, 1, 18, 10, 0);
      final time2 = DateTime(2026, 1, 18, 10, 20); // 20分钟后

      final diff = time2.difference(time1).inMinutes;

      expect(diff, 20);
      expect(diff < 30, true, reason: '应该被防抖过滤');
    });

    test('防抖机制：应该允许30分钟后的触发', () {
      final time1 = DateTime(2026, 1, 18, 10, 0);
      final time2 = DateTime(2026, 1, 18, 10, 35); // 35分钟后

      final diff = time2.difference(time1).inMinutes;

      expect(diff, 35);
      expect(diff >= 30, true, reason: '应该允许新的检测');
    });

    test('记录匹配：应该找到15分钟窗口内的匹配记录', () {
      final eventTime = DateTime(2026, 1, 18, 10, 0);
      final existingRecords = [
        createFeedingRecord(DateTime(2026, 1, 18, 9, 50), 12.0), // -10分钟
        createFeedingRecord(DateTime(2026, 1, 18, 10, 5), 15.0), // +5分钟
        createFeedingRecord(DateTime(2026, 1, 18, 10, 30), 18.0), // +30分钟
      ];

      final isRecorded = _isEventRecorded(eventTime, existingRecords, 15);

      expect(isRecorded, true, reason: '应该匹配到 +5分钟 的记录');
    });

    test('记录匹配：不应该匹配超出15分钟窗口的记录', () {
      final eventTime = DateTime(2026, 1, 18, 10, 0);
      final existingRecords = [
        createFeedingRecord(DateTime(2026, 1, 18, 9, 30), 12.0), // -30分钟
        createFeedingRecord(DateTime(2026, 1, 18, 10, 20), 15.0), // +20分钟
      ];

      final isRecorded = _isEventRecorded(eventTime, existingRecords, 15);

      expect(isRecorded, false, reason: '所有记录都超出匹配窗口');
    });

    test('记录匹配：空记录列表应该返回 false', () {
      final eventTime = DateTime(2026, 1, 18, 10, 0);
      final existingRecords = <FeedingRecord>[];

      final isRecorded = _isEventRecorded(eventTime, existingRecords, 15);

      expect(isRecorded, false, reason: '没有记录应该返回 false');
    });

    test('边界测试：恰好在15分钟边界的记录应该匹配', () {
      final eventTime = DateTime(2026, 1, 18, 10, 0);
      final existingRecords = [
        createFeedingRecord(DateTime(2026, 1, 18, 9, 45), 12.0), // 恰好 -15分钟
        createFeedingRecord(DateTime(2026, 1, 18, 10, 15), 15.0), // 恰好 +15分钟
      ];

      final isRecorded = _isEventRecorded(eventTime, existingRecords, 15);

      expect(isRecorded, true, reason: '边界值应该被匹配');
    });

    test('综合场景：模拟完整的检测流程', () {
      // 模拟原始数据：3次投料，每次间隔45分钟
      final points = [
        createWeightPoint(DateTime(2026, 1, 18, 9, 0), 50.0),
        createWeightPoint(DateTime(2026, 1, 18, 9, 5), 65.0), // 第1次投料 +15kg
        createWeightPoint(DateTime(2026, 1, 18, 9, 10), 67.0), // 小波动 +2kg
        createWeightPoint(DateTime(2026, 1, 18, 10, 0), 82.0), // 第2次投料 +15kg
        createWeightPoint(DateTime(2026, 1, 18, 11, 0), 98.0), // 第3次投料 +16kg
      ];

      // 后端已有记录（漏掉了第2次）
      final existingRecords = [
        createFeedingRecord(DateTime(2026, 1, 18, 9, 5), 15.0), // 第1次已记录
        createFeedingRecord(DateTime(2026, 1, 18, 11, 0), 16.0), // 第3次已记录
      ];

      // 模拟检测逻辑
      final detectedEvents = <DateTime>[];
      final missingEvents = <DateTime>[];
      DateTime? lastTrigger;

      for (int i = 1; i < points.length; i++) {
        final diff = _calculateWeightDiff(points[i - 1], points[i]);

        if (diff <= 10.0) continue;

        final eventTime = points[i].time;

        // 防抖
        if (lastTrigger != null &&
            eventTime.difference(lastTrigger).inMinutes < 30) {
          continue;
        }

        detectedEvents.add(eventTime);

        // 检查是否已记录
        if (!_isEventRecorded(eventTime, existingRecords, 15)) {
          missingEvents.add(eventTime);
        }

        lastTrigger = eventTime;
      }

      expect(detectedEvents.length, 3, reason: '应该检测到3次投料');
      expect(missingEvents.length, 1, reason: '应该发现1次遗漏');
      expect(
        missingEvents.first,
        DateTime(2026, 1, 18, 10, 0),
        reason: '遗漏的应该是第2次投料',
      );
    });
  });
}

// ==================== 测试辅助方法 ====================
// 这些方法复制自 data_history_page.dart，用于单元测试

/// 计算两个数据点之间的重量差值
double _calculateWeightDiff(HistoryDataPoint prev, HistoryDataPoint curr) {
  final prevWeight = (prev.fields['weight'] as num?)?.toDouble() ?? 0.0;
  final currWeight = (curr.fields['weight'] as num?)?.toDouble() ?? 0.0;
  return currWeight - prevWeight;
}

/// 检查事件是否已在后端记录中
bool _isEventRecorded(
  DateTime eventTime,
  List<FeedingRecord> records,
  int matchWindowMins,
) {
  return records.any((record) {
    final timeDiff = record.time.difference(eventTime).inMinutes.abs();
    return timeDiff <= matchWindowMins;
  });
}
