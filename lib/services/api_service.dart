import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news.dart';
import '../models/user.dart';
import '../models/match.dart';

// API服务Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class ApiService {
  late final Dio _dio;
  static const String baseUrl = 'http://localhost:8000';

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 添加拦截器用于日志和错误处理
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // print('请求: ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // print('响应: ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          // print('网络错误: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  // 设置认证Token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // 清除认证Token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // 获取新闻列表
  Future<NewsResponse> getNews({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': limit,
        if (category != null) 'category': category,
      };

      final response = await _dio.get(
        '/api/v1/news',
        queryParameters: queryParams,
      );

      return NewsResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 获取新闻详情
  Future<News> getNewsDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/news/$id');
      return News.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 获取比赛列表
  Future<MatchResponse> getMatches({
    DateTime? date,
    String? competition,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }
      if (competition != null) {
        queryParams['competition'] = competition;
      }
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await _dio.get(
        '/api/v1/matches',
        queryParameters: queryParams,
      );

      return MatchResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 获取比赛详情
  Future<Match> getMatchDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/matches/$id');
      return Match.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 用户注册
  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/register',
        data: request.toJson(),
      );

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 用户登录
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login',
        data: request.toJson(),
      );

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 获取用户信息
  Future<User> getUserProfile() async {
    try {
      final response = await _dio.get('/api/v1/user/profile');
      return User.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // 错误处理
  ApiException _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException(
            code: 'TIMEOUT',
            message: '网络连接超时，请检查网络设置',
          );
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          final data = error.response?.data;
          if (data is Map<String, dynamic> && data.containsKey('error')) {
            return ApiException(
              code: data['error']['code'] ?? 'SERVER_ERROR',
              message: data['error']['message'] ?? '服务器错误',
              statusCode: statusCode,
            );
          }
          return ApiException(
            code: 'HTTP_ERROR',
            message: '服务器错误 ($statusCode)',
            statusCode: statusCode,
          );
        case DioExceptionType.cancel:
          return const ApiException(
            code: 'CANCELLED',
            message: '请求已取消',
          );
        case DioExceptionType.badCertificate:
          return const ApiException(
            code: 'CERTIFICATE_ERROR',
            message: '证书验证失败',
          );
        case DioExceptionType.connectionError:
          return const ApiException(
            code: 'CONNECTION_ERROR',
            message: '网络连接失败，请检查网络设置',
          );
        default:
          return const ApiException(
            code: 'UNKNOWN',
            message: '未知网络错误',
          );
      }
    }
    
    return ApiException(
      code: 'UNKNOWN',
      message: error.toString(),
    );
  }
}

// API异常类
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'ApiException: $message ($code)';
} 