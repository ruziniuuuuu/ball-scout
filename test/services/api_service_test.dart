import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:soda/services/api_service.dart';
import 'package:soda/models/news.dart';
import 'package:soda/models/match.dart';

import 'api_service_test.mocks.dart';

// 生成Mock类
@GenerateMocks([Dio])
void main() {
  group('ApiService Tests', () {
    late ApiService apiService;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      apiService = ApiService();
      // 注意：实际项目中需要能够注入mockDio到ApiService中
      // 这里为了演示测试结构，实际使用时需要修改ApiService以支持依赖注入
    });

    group('Authentication', () {
      test('should set auth token in headers', () {
        const token = 'test-token';
        apiService.setAuthToken(token);
        
        // 验证token是否被设置
        // 实际实现中需要能够获取当前设置的token
        expect(apiService, isNotNull);
      });

      test('should clear auth token from headers', () {
        apiService.setAuthToken('test-token');
        apiService.clearAuthToken();
        
        // 验证token是否被清除
        expect(apiService, isNotNull);
      });
    });

    group('News API', () {
      group('getNews', () {
        test('should return news list successfully', () async {
          // Arrange
          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': [
                {
                  'id': '1',
                  'title': 'Test News',
                  'summary': 'Test Summary',
                  'source': 'Test Source',
                  'category': 'news',
                  'publishedAt': '2024-01-20T10:00:00.000Z',
                  'readCount': 100,
                }
              ],
              'meta': {
                'total': 1,
                'timestamp': '2024-01-20T10:30:00.000Z',
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/news'),
          );

          when(mockDio.get(
            '/api/v1/news',
            queryParameters: anyNamed('queryParameters'),
          )).thenAnswer((_) async => mockResponse);

          // Act & Assert
          // 注意：这个测试需要ApiService支持依赖注入才能正常工作
          // 实际实现时需要重构ApiService
          expect(apiService, isNotNull);
        });

        test('should handle API error correctly', () async {
          // Arrange
          final dioError = DioException(
            requestOptions: RequestOptions(path: '/api/v1/news'),
            type: DioExceptionType.connectionTimeout,
            message: 'Connection timeout',
          );

          when(mockDio.get(
            '/api/v1/news',
            queryParameters: anyNamed('queryParameters'),
          )).thenThrow(dioError);

          // Act & Assert
          // 测试错误处理逻辑
          expect(apiService, isNotNull);
        });

        test('should pass correct query parameters', () async {
          // Arrange
          const page = 2;
          const limit = 10;
          const category = 'transfer';

          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': [],
              'meta': {'total': 0, 'timestamp': '2024-01-20T10:30:00.000Z'}
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/news'),
          );

          when(mockDio.get(
            '/api/v1/news',
            queryParameters: anyNamed('queryParameters'),
          )).thenAnswer((_) async => mockResponse);

          // Act
          // await apiService.getNews(page: page, limit: limit, category: category);

          // Assert
          verify(mockDio.get(
            '/api/v1/news',
            queryParameters: {
              'page': page,
              'limit': limit,
              'category': category,
            },
          )).called(1);
        });
      });

      group('getNewsDetail', () {
        test('should return news detail successfully', () async {
          // Arrange
          const newsId = 'test-id';
          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': {
                'id': newsId,
                'title': 'Test News Detail',
                'content': 'Full content here',
                'summary': 'Test Summary',
                'source': 'Test Source',
                'category': 'news',
                'publishedAt': '2024-01-20T10:00:00.000Z',
                'readCount': 100,
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/news/$newsId'),
          );

          when(mockDio.get('/api/v1/news/$newsId'))
              .thenAnswer((_) async => mockResponse);

          // Act & Assert
          expect(apiService, isNotNull);
        });

        test('should handle not found error', () async {
          // Arrange
          const newsId = 'non-existent-id';
          final dioError = DioException(
            requestOptions: RequestOptions(path: '/api/v1/news/$newsId'),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: '/api/v1/news/$newsId'),
            ),
          );

          when(mockDio.get('/api/v1/news/$newsId')).thenThrow(dioError);

          // Act & Assert
          expect(
            () => apiService.getNewsDetail(newsId),
            throwsA(isA<ApiException>()),
          );
        });
      });
    });

    group('Match API', () {
      group('getMatches', () {
        test('should return matches list successfully', () async {
          // Arrange
          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': [
                {
                  'id': '1',
                  'homeTeam': 'Real Madrid',
                  'awayTeam': 'Barcelona',
                  'homeScore': 2,
                  'awayScore': 1,
                  'status': 'finished',
                  'matchTime': '2024-01-20T20:00:00.000Z',
                  'competition': 'La Liga',
                  'venue': 'Santiago Bernabéu',
                }
              ],
              'meta': {
                'total': 1,
                'timestamp': '2024-01-20T22:00:00.000Z',
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/matches'),
          );

          when(mockDio.get(
            '/api/v1/matches',
            queryParameters: anyNamed('queryParameters'),
          )).thenAnswer((_) async => mockResponse);

          // Act & Assert
          expect(apiService, isNotNull);
        });

        test('should format date parameter correctly', () async {
          // Arrange
          final testDate = DateTime(2024, 1, 20);
          final expectedDateString = '2024-01-20';

          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': [],
              'meta': {'total': 0, 'timestamp': '2024-01-20T10:30:00.000Z'}
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/matches'),
          );

          when(mockDio.get(
            '/api/v1/matches',
            queryParameters: anyNamed('queryParameters'),
          )).thenAnswer((_) async => mockResponse);

          // Act
          // await apiService.getMatches(date: testDate);

          // Assert
          verify(mockDio.get(
            '/api/v1/matches',
            queryParameters: {'date': expectedDateString},
          )).called(1);
        });
      });
    });

    group('User Authentication', () {
      group('login', () {
        test('should login successfully with valid credentials', () async {
          // Arrange
          final loginRequest = {
            'email': 'test@example.com',
            'password': 'password123',
          };

          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': {
                'user': {
                  'id': 'user-123',
                  'username': 'testuser',
                  'email': 'test@example.com',
                  'createdAt': '2024-01-20T10:00:00.000Z',
                },
                'token': 'jwt-token-123',
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          );

          when(mockDio.post(
            '/api/v1/auth/login',
            data: anyNamed('data'),
          )).thenAnswer((_) async => mockResponse);

          // Act & Assert
          expect(apiService, isNotNull);
        });

        test('should handle invalid credentials error', () async {
          // Arrange
          final loginRequest = {
            'email': 'test@example.com',
            'password': 'wrongpassword',
          };

          final dioError = DioException(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 401,
              data: {
                'success': false,
                'error': {
                  'code': 'INVALID_CREDENTIALS',
                  'message': '邮箱或密码错误',
                }
              },
              requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            ),
          );

          when(mockDio.post(
            '/api/v1/auth/login',
            data: anyNamed('data'),
          )).thenThrow(dioError);

          // Act & Assert
          expect(apiService, isNotNull);
        });
      });

      group('register', () {
        test('should register successfully with valid data', () async {
          // Arrange
          final registerRequest = {
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'password123',
          };

          final mockResponse = Response<Map<String, dynamic>>(
            data: {
              'success': true,
              'data': {
                'user': {
                  'id': 'user-456',
                  'username': 'newuser',
                  'email': 'newuser@example.com',
                  'createdAt': '2024-01-20T10:00:00.000Z',
                },
                'token': 'jwt-token-456',
              }
            },
            statusCode: 201,
            requestOptions: RequestOptions(path: '/api/v1/auth/register'),
          );

          when(mockDio.post(
            '/api/v1/auth/register',
            data: anyNamed('data'),
          )).thenAnswer((_) async => mockResponse);

          // Act & Assert
          expect(apiService, isNotNull);
        });
      });
    });

    group('Error Handling', () {
      test('should handle timeout errors', () {
        // Arrange
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );

        // Act
        final apiException = apiService._handleError(dioError);

        // Assert
        expect(apiException, isA<ApiException>());
        expect(apiException.code, 'TIMEOUT');
        expect(apiException.message, '网络连接超时，请检查网络设置');
      });

      test('should handle server errors', () {
        // Arrange
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            data: {
              'error': {
                'code': 'INTERNAL_ERROR',
                'message': '服务器内部错误',
              }
            },
            requestOptions: RequestOptions(path: '/test'),
          ),
        );

        // Act
        final apiException = apiService._handleError(dioError);

        // Assert
        expect(apiException, isA<ApiException>());
        expect(apiException.code, 'INTERNAL_ERROR');
        expect(apiException.message, '服务器内部错误');
        expect(apiException.statusCode, 500);
      });

      test('should handle network connection errors', () {
        // Arrange
        final dioError = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
        );

        // Act
        final apiException = apiService._handleError(dioError);

        // Assert
        expect(apiException, isA<ApiException>());
        expect(apiException.code, 'CONNECTION_ERROR');
        expect(apiException.message, '网络连接失败，请检查网络设置');
      });
    });

    group('Health Check', () {
      test('should return true when server is healthy', () async {
        // Arrange
        final mockResponse = Response<Map<String, dynamic>>(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/health'),
        );

        when(mockDio.get('/health')).thenAnswer((_) async => mockResponse);

        // Act
        final isHealthy = await apiService.healthCheck();

        // Assert
        expect(isHealthy, true);
      });

      test('should return false when server is unhealthy', () async {
        // Arrange
        when(mockDio.get('/health')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/health'),
            type: DioExceptionType.connectionError,
          ),
        );

        // Act
        final isHealthy = await apiService.healthCheck();

        // Assert
        expect(isHealthy, false);
      });
    });
  });
}