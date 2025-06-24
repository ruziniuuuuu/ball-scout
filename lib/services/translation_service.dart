import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 翻译服务Provider
final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});

// 简化的翻译请求类
class SimpleTranslationRequest {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final String domain;
  final String priority;

  const SimpleTranslationRequest({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.domain = 'football',
    this.priority = 'medium',
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'domain': domain,
        'priority': priority,
      };
}

// 简化的翻译结果类
class SimpleTranslationResult {
  final String translatedText;
  final double confidence;
  final String model;
  final int processingTime;
  final double qualityScore;

  const SimpleTranslationResult({
    required this.translatedText,
    required this.confidence,
    required this.model,
    required this.processingTime,
    required this.qualityScore,
  });

  factory SimpleTranslationResult.fromJson(Map<String, dynamic> json) {
    return SimpleTranslationResult(
      translatedText: json['translatedText'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      model: json['model'] ?? '',
      processingTime: json['processingTime'] ?? 0,
      qualityScore: (json['qualityScore'] ?? 0.0).toDouble(),
    );
  }
}

class TranslationService {
  late final Dio _dio;
  static const String baseUrl = 'http://localhost:8000';

  TranslationService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 添加拦截器用于日志和错误处理
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🌐 翻译请求: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ 翻译响应: ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ 翻译错误: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// 单个文本翻译
  Future<SimpleTranslationResult> translate({
    required String text,
    required String sourceLanguage,
    String targetLanguage = 'zh-CN',
    String domain = 'football',
    String priority = 'medium',
  }) async {
    try {
      final request = SimpleTranslationRequest(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        domain: domain,
        priority: priority,
      );

      final response = await _dio.post(
        '/api/v1/translate',
        data: request.toJson(),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return SimpleTranslationResult.fromJson(response.data['data']);
      } else {
        throw TranslationException(
          code: response.data['error']?['code'] ?? 'UNKNOWN_ERROR',
          message: response.data['error']?['message'] ?? '翻译失败',
        );
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取翻译服务状态
  Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final response = await _dio.get('/api/v1/translate/status');

      if (response.statusCode == 200) {
        return response.data['data'] ?? {};
      } else {
        throw TranslationException(
          code: 'STATUS_ERROR',
          message: '无法获取服务状态',
        );
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 健康检查
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get('/api/v1/translate/health');
      return response.data['data'] ?? {};
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 智能翻译新闻内容
  Future<String> translateNewsContent({
    required String content,
    required String sourceLanguage,
    String targetLanguage = 'zh-CN',
  }) async {
    try {
      final result = await translate(
        text: content,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        domain: 'football',
        priority: 'high',
      );

      return result.translatedText;
    } catch (e) {
      print('新闻翻译失败: $e');
      return content; // 翻译失败时返回原文
    }
  }

  /// 错误处理
  TranslationException _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const TranslationException(
            code: 'TIMEOUT',
            message: '翻译请求超时，请稍后重试',
          );
        case DioExceptionType.connectionError:
          return const TranslationException(
            code: 'CONNECTION_ERROR',
            message: '无法连接到翻译服务',
          );
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          final message =
              error.response?.data?['error']?['message'] ?? '翻译服务错误';
          return TranslationException(
            code: 'HTTP_$statusCode',
            message: message,
          );
        default:
          return const TranslationException(
            code: 'UNKNOWN',
            message: '未知网络错误',
          );
      }
    }

    return TranslationException(
      code: 'UNKNOWN',
      message: error.toString(),
    );
  }
}

/// 翻译异常类
class TranslationException implements Exception {
  final String code;
  final String message;

  const TranslationException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'TranslationException: $message ($code)';
}

/// 翻译状态Provider
final translationStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(translationServiceProvider);
  return await service.getServiceStatus();
});
