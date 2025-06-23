import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/reading_history.dart';
import '../models/news.dart';

// 阅读历史服务Provider
final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  return ReadingHistoryService();
});

// 阅读历史状态Provider
final readingHistoryProvider = StateNotifierProvider<ReadingHistoryNotifier, List<ReadingHistory>>((ref) {
  return ReadingHistoryNotifier(ref.read(readingHistoryServiceProvider));
});

class ReadingHistoryService {
  static const String _historyKey = 'reading_history';
  static const int _maxHistoryItems = 100; // 最多保存100条记录

  // 获取所有阅读历史
  Future<List<ReadingHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    
    return historyJson
        .map((json) => ReadingHistory.fromJson(jsonDecode(json)))
        .toList()
        ..sort((a, b) => b.readAt.compareTo(a.readAt)); // 按时间倒序排列
  }

  // 添加阅读记录
  Future<void> addHistory(ReadingHistory history) async {
    final histories = await getHistory();
    
    // 检查是否已存在相同新闻的记录，存在则更新，不存在则添加
    final existingIndex = histories.indexWhere((h) => h.news.id == history.news.id);
    
    if (existingIndex != -1) {
      // 更新现有记录
      histories[existingIndex] = history;
    } else {
      // 添加新记录
      histories.insert(0, history);
    }

    // 限制历史记录数量
    if (histories.length > _maxHistoryItems) {
      histories.removeRange(_maxHistoryItems, histories.length);
    }

    await _saveHistories(histories);
  }

  // 删除指定的阅读记录
  Future<void> removeHistory(String newsId) async {
    final histories = await getHistory();
    histories.removeWhere((h) => h.news.id == newsId);
    await _saveHistories(histories);
  }

  // 清空所有阅读历史
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // 根据时间范围获取阅读历史
  Future<List<ReadingHistory>> getHistoryByDateRange(DateTime start, DateTime end) async {
    final histories = await getHistory();
    return histories.where((h) => 
      h.readAt.isAfter(start) && h.readAt.isBefore(end)
    ).toList();
  }

  // 获取今日阅读历史
  Future<List<ReadingHistory>> getTodayHistory() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getHistoryByDateRange(startOfDay, endOfDay);
  }

  // 获取阅读统计信息
  Future<ReadingStats> getReadingStats() async {
    final histories = await getHistory();
    final now = DateTime.now();
    
    // 今日阅读数量
    final todayCount = histories.where((h) => 
      h.readAt.year == now.year && 
      h.readAt.month == now.month && 
      h.readAt.day == now.day
    ).length;

    // 本周阅读数量
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekCount = histories.where((h) => h.readAt.isAfter(weekStart)).length;

    // 总阅读时长
    final totalDuration = histories.fold<int>(0, (sum, h) => sum + h.duration);

    // 最常阅读的分类
    final categoryCount = <String, int>{};
    for (final h in histories) {
      categoryCount[h.news.category] = (categoryCount[h.news.category] ?? 0) + 1;
    }
    final mostReadCategory = categoryCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return ReadingStats(
      totalCount: histories.length,
      todayCount: todayCount,
      weekCount: weekCount,
      totalDuration: totalDuration,
      mostReadCategory: mostReadCategory,
    );
  }

  // 检查新闻是否已读
  Future<bool> hasRead(String newsId) async {
    final histories = await getHistory();
    return histories.any((h) => h.news.id == newsId);
  }

  // 保存历史记录到本地
  Future<void> _saveHistories(List<ReadingHistory> histories) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = histories.map((h) => jsonEncode(h.toJson())).toList();
    await prefs.setStringList(_historyKey, historyJson);
  }
}

class ReadingHistoryNotifier extends StateNotifier<List<ReadingHistory>> {
  final ReadingHistoryService _service;

  ReadingHistoryNotifier(this._service) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    state = await _service.getHistory();
  }

  Future<void> addHistory(ReadingHistory history) async {
    await _service.addHistory(history);
    await _loadHistory(); // 重新加载以确保数据同步
  }

  Future<void> removeHistory(String newsId) async {
    await _service.removeHistory(newsId);
    state = state.where((h) => h.news.id != newsId).toList();
  }

  Future<void> clearHistory() async {
    await _service.clearHistory();
    state = [];
  }

  // 添加新闻阅读记录
  Future<void> addNewsRead(News news, {int duration = 0, double progress = 0.0}) async {
    final history = ReadingHistory.create(news, duration: duration, progress: progress);
    await addHistory(history);
  }

  // 更新阅读进度
  Future<void> updateProgress(String newsId, double progress, int duration) async {
    final histories = await _service.getHistory();
    final existingIndex = histories.indexWhere((h) => h.news.id == newsId);
    
    if (existingIndex != -1) {
      final updated = histories[existingIndex].copyWith(
        progress: progress,
        duration: duration,
        readAt: DateTime.now(), // 更新阅读时间
      );
      await _service.addHistory(updated);
      await _loadHistory();
    }
  }
}

// 阅读统计数据类
class ReadingStats {
  final int totalCount;
  final int todayCount;
  final int weekCount;
  final int totalDuration; // 总阅读时长（秒）
  final String mostReadCategory;

  const ReadingStats({
    required this.totalCount,
    required this.todayCount,
    required this.weekCount,
    required this.totalDuration,
    required this.mostReadCategory,
  });

  // 获取总阅读时长描述
  String get totalDurationDescription {
    final minutes = totalDuration ~/ 60;
    final hours = minutes ~/ 60;
    
    if (hours > 0) {
      return '${hours}小时${minutes % 60}分钟';
    } else {
      return '${minutes}分钟';
    }
  }

  // 获取最常读分类的显示名称
  String get mostReadCategoryDisplayName {
    switch (mostReadCategory) {
      case 'transfer':
        return '转会';
      case 'match':
        return '比赛';
      case 'news':
        return '新闻';
      case 'analysis':
        return '分析';
      default:
        return '其他';
    }
  }
} 