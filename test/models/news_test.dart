import 'package:flutter_test/flutter_test.dart';
import 'package:soda/models/news.dart';

void main() {
  group('News Model Tests', () {
    late News testNews;

    setUp(() {
      testNews = const News(
        id: '1',
        title: 'Test News Title',
        summary: 'Test news summary',
        source: 'Test Source',
        category: 'news',
        publishedAt: '2024-01-20T10:00:00.000Z',
        readCount: 100,
        imageUrl: 'https://example.com/image.jpg',
        content: 'Test news content',
      );
    });

    group('News Model Creation', () {
      test('should create News instance with all required fields', () {
        expect(testNews.id, '1');
        expect(testNews.title, 'Test News Title');
        expect(testNews.summary, 'Test news summary');
        expect(testNews.source, 'Test Source');
        expect(testNews.category, 'news');
        expect(testNews.readCount, 100);
      });

      test('should handle optional fields correctly', () {
        const newsWithoutOptionals = News(
          id: '2',
          title: 'Test Title',
          summary: 'Test Summary',
          source: 'Test Source',
          category: 'match',
          publishedAt: '2024-01-20T10:00:00.000Z',
          readCount: 0,
        );

        expect(newsWithoutOptionals.imageUrl, isNull);
        expect(newsWithoutOptionals.content, isNull);
      });
    });

    group('Category Display Name', () {
      test('should return correct display name for transfer category', () {
        final transferNews = testNews.copyWith(category: 'transfer');
        expect(transferNews.categoryDisplayName, '转会');
      });

      test('should return correct display name for match category', () {
        final matchNews = testNews.copyWith(category: 'match');
        expect(matchNews.categoryDisplayName, '比赛');
      });

      test('should return correct display name for news category', () {
        expect(testNews.categoryDisplayName, '新闻');
      });

      test('should return correct display name for analysis category', () {
        final analysisNews = testNews.copyWith(category: 'analysis');
        expect(analysisNews.categoryDisplayName, '分析');
      });

      test('should return default name for unknown category', () {
        final unknownNews = testNews.copyWith(category: 'unknown');
        expect(unknownNews.categoryDisplayName, '其他');
      });
    });

    group('Category Color', () {
      test('should return correct color for transfer category', () {
        final transferNews = testNews.copyWith(category: 'transfer');
        expect(transferNews.categoryColor, '#FF6B35');
      });

      test('should return correct color for match category', () {
        final matchNews = testNews.copyWith(category: 'match');
        expect(matchNews.categoryColor, '#007BFF');
      });

      test('should return correct color for news category', () {
        expect(testNews.categoryColor, '#00C851');
      });

      test('should return correct color for analysis category', () {
        final analysisNews = testNews.copyWith(category: 'analysis');
        expect(analysisNews.categoryColor, '#AA66CC');
      });

      test('should return default color for unknown category', () {
        final unknownNews = testNews.copyWith(category: 'unknown');
        expect(unknownNews.categoryColor, '#7F8C8D');
      });
    });

    group('Time Ago Text', () {
      test('should return "刚刚" for very recent news', () {
        final now = DateTime.now();
        final recentNews = testNews.copyWith(
          publishedAt: now.toIso8601String(),
        );
        expect(recentNews.timeAgoText, '刚刚');
      });

      test('should return minutes ago for news within an hour', () {
        final thirtyMinutesAgo = DateTime.now()
            .subtract(const Duration(minutes: 30))
            .toIso8601String();
        final recentNews = testNews.copyWith(publishedAt: thirtyMinutesAgo);
        expect(recentNews.timeAgoText, '30分钟前');
      });

      test('should return hours ago for news within a day', () {
        final twoHoursAgo = DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String();
        final recentNews = testNews.copyWith(publishedAt: twoHoursAgo);
        expect(recentNews.timeAgoText, '2小时前');
      });

      test('should return days ago for older news', () {
        final threeDaysAgo = DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String();
        final oldNews = testNews.copyWith(publishedAt: threeDaysAgo);
        expect(oldNews.timeAgoText, '3天前');
      });

      test('should handle invalid date format gracefully', () {
        final invalidNews = testNews.copyWith(publishedAt: 'invalid-date');
        expect(invalidNews.timeAgoText, '未知时间');
      });
    });

    group('JSON Serialization', () {
      test('should convert to JSON correctly', () {
        final json = testNews.toJson();
        
        expect(json['id'], '1');
        expect(json['title'], 'Test News Title');
        expect(json['summary'], 'Test news summary');
        expect(json['source'], 'Test Source');
        expect(json['category'], 'news');
        expect(json['publishedAt'], '2024-01-20T10:00:00.000Z');
        expect(json['readCount'], 100);
        expect(json['imageUrl'], 'https://example.com/image.jpg');
        expect(json['content'], 'Test news content');
      });

      test('should create from JSON correctly', () {
        final json = {
          'id': '2',
          'title': 'JSON News Title',
          'summary': 'JSON news summary',
          'source': 'JSON Source',
          'category': 'transfer',
          'publishedAt': '2024-01-20T15:00:00.000Z',
          'readCount': 200,
          'imageUrl': 'https://example.com/json-image.jpg',
          'content': 'JSON news content',
        };

        final news = News.fromJson(json);
        
        expect(news.id, '2');
        expect(news.title, 'JSON News Title');
        expect(news.summary, 'JSON news summary');
        expect(news.source, 'JSON Source');
        expect(news.category, 'transfer');
        expect(news.publishedAt, '2024-01-20T15:00:00.000Z');
        expect(news.readCount, 200);
        expect(news.imageUrl, 'https://example.com/json-image.jpg');
        expect(news.content, 'JSON news content');
      });
    });

    group('Copy With', () {
      test('should create new instance with updated values', () {
        final updatedNews = testNews.copyWith(
          title: 'Updated Title',
          readCount: 500,
        );

        expect(updatedNews.title, 'Updated Title');
        expect(updatedNews.readCount, 500);
        expect(updatedNews.id, testNews.id); // unchanged
        expect(updatedNews.source, testNews.source); // unchanged
      });

      test('should return same instance when no changes made', () {
        final sameNews = testNews.copyWith();
        expect(sameNews.id, testNews.id);
        expect(sameNews.title, testNews.title);
        expect(sameNews.readCount, testNews.readCount);
      });
    });
  });

  group('NewsResponse Tests', () {
    test('should create NewsResponse from JSON', () {
      final json = {
        'success': true,
        'data': [
          {
            'id': '1',
            'title': 'News 1',
            'summary': 'Summary 1',
            'source': 'Source 1',
            'category': 'news',
            'publishedAt': '2024-01-20T10:00:00.000Z',
            'readCount': 100,
          }
        ],
        'meta': {
          'total': 1,
          'timestamp': '2024-01-20T10:30:00.000Z',
        }
      };

      final response = NewsResponse.fromJson(json);
      
      expect(response.success, true);
      expect(response.data.length, 1);
      expect(response.data[0].id, '1');
      expect(response.meta.total, 1);
    });
  });

  group('NewsMetadata Tests', () {
    test('should create NewsMetadata from JSON', () {
      final json = {
        'total': 100,
        'timestamp': '2024-01-20T10:30:00.000Z',
      };

      final metadata = NewsMetadata.fromJson(json);
      
      expect(metadata.total, 100);
      expect(metadata.timestamp, '2024-01-20T10:30:00.000Z');
    });
  });
}