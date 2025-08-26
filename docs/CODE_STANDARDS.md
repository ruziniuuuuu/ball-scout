# 球探社代码规范

## 概述

本文档定义了球探社项目的代码编写规范，旨在确保代码的一致性、可读性和可维护性。

## 通用原则

### 命名规范

1. **使用有意义的名称**
   ```dart
   // Good
   final List<News> featuredNewsList;
   final User currentUser;
   
   // Bad
   final List<News> list;
   final User u;
   ```

2. **避免缩写和简写**
   ```dart
   // Good
   final String categoryName;
   final int maximumRetryCount;
   
   // Bad
   final String catName;
   final int maxRetryCnt;
   ```

3. **使用动词描述函数功能**
   ```dart
   // Good
   Future<List<News>> fetchNewsList();
   bool validateEmailFormat(String email);
   
   // Bad
   Future<List<News>> newsList();
   bool email(String email);
   ```

### 注释规范

1. **函数和类注释**
   ```dart
   /// 获取新闻列表的服务类
   /// 
   /// 提供新闻数据的获取、缓存和筛选功能。
   /// 支持分页、分类筛选等功能。
   class NewsService {
     /// 获取新闻列表
     /// 
     /// [page] 页码，从1开始
     /// [limit] 每页数量，默认20
     /// [category] 新闻分类，可选
     /// 
     /// Returns 包含新闻数据和元信息的响应对象
     /// Throws [ApiException] 当网络请求失败时
     Future<NewsResponse> fetchNews({
       int page = 1,
       int limit = 20,
       String? category,
     }) async {
       // 实现代码...
     }
   }
   ```

2. **复杂逻辑注释**
   ```dart
   // 计算新闻发布时间的相对显示文字
   // 规则：1小时内显示分钟，1天内显示小时，超过1天显示天数
   String get timeAgoText {
     final publishTime = DateTime.parse(publishedAt);
     final now = DateTime.now();
     final difference = now.difference(publishTime);
     
     if (difference.inDays > 0) {
       return '${difference.inDays}天前';
     }
     // 其余逻辑...
   }
   ```

## Flutter 代码规范

### 文件结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── news.dart
│   ├── user.dart
│   └── match.dart
├── services/                 # 业务逻辑服务
│   ├── api_service.dart
│   ├── auth_service.dart
│   └── theme_service.dart
├── screens/                  # 页面组件
│   ├── auth/
│   ├── news/
│   └── profile/
├── widgets/                  # 通用组件
│   ├── common/
│   ├── news/
│   └── user/
└── utils/                    # 工具函数
    ├── constants.dart
    ├── theme.dart
    └── validators.dart
```

### Widget 规范

1. **使用 ConsumerWidget 进行状态管理**
   ```dart
   class NewsScreen extends ConsumerWidget {
     const NewsScreen({super.key});

     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final newsState = ref.watch(newsListProvider);
       
       return Scaffold(
         appBar: AppBar(title: const Text('新闻')),
         body: _buildBody(newsState),
       );
     }
     
     Widget _buildBody(AsyncValue<List<News>> newsState) {
       return newsState.when(
         data: (newsList) => _buildNewsList(newsList),
         loading: () => const LoadingWidget(),
         error: (error, stack) => ErrorWidget(error: error),
       );
     }
   }
   ```

2. **提取复用组件**
   ```dart
   class NewsCard extends StatelessWidget {
     const NewsCard({
       super.key,
       required this.news,
       this.onTap,
     });

     final News news;
     final VoidCallback? onTap;

     @override
     Widget build(BuildContext context) {
       return Card(
         child: InkWell(
           onTap: onTap,
           child: Padding(
             padding: const EdgeInsets.all(16),
             child: _buildContent(),
           ),
         ),
       );
     }
   }
   ```

3. **使用 const 构造函数优化性能**
   ```dart
   // Good
   const LoadingWidget();
   const SizedBox(height: 16);
   
   // Bad
   LoadingWidget();
   SizedBox(height: 16);
   ```

### 状态管理

1. **使用 Riverpod Provider**
   ```dart
   // 状态定义
   final newsListProvider = StateNotifierProvider<NewsListNotifier, AsyncValue<List<News>>>((ref) {
     return NewsListNotifier(ref.read(apiServiceProvider));
   });

   // 状态管理类
   class NewsListNotifier extends StateNotifier<AsyncValue<List<News>>> {
     NewsListNotifier(this._apiService) : super(const AsyncValue.loading());

     final ApiService _apiService;
     
     /// 加载新闻列表
     Future<void> loadNews({String? category}) async {
       state = const AsyncValue.loading();
       
       try {
         final response = await _apiService.getNews(category: category);
         state = AsyncValue.data(response.data);
       } catch (error, stack) {
         state = AsyncValue.error(error, stack);
       }
     }
   }
   ```

2. **错误处理**
   ```dart
   Future<void> _handleApiCall<T>(Future<T> Function() apiCall) async {
     try {
       await apiCall();
     } on ApiException catch (e) {
       // 处理API异常
       _showErrorSnackBar(e.message);
     } catch (e) {
       // 处理其他异常
       _showErrorSnackBar('发生未知错误');
     }
   }
   ```

### 数据模型

1. **使用 JSON 序列化**
   ```dart
   @JsonSerializable()
   class News {
     const News({
       required this.id,
       required this.title,
       required this.summary,
       this.imageUrl,
     });

     final String id;
     final String title;
     final String summary;
     final String? imageUrl;

     factory News.fromJson(Map<String, dynamic> json) => _$NewsFromJson(json);
     Map<String, dynamic> toJson() => _$NewsToJson(this);
   }
   ```

2. **数据验证**
   ```dart
   class User {
     const User({required this.email, required this.username});
     
     final String email;
     final String username;
     
     /// 验证邮箱格式
     bool get isValidEmail {
       return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
     }
     
     /// 验证用户名长度
     bool get isValidUsername {
       return username.length >= 3 && username.length <= 20;
     }
   }
   ```

## Deno TypeScript 规范

### 文件结构

```
backend/
├── mod.ts                    # 应用入口
├── config.ts                 # 配置文件
├── deps.ts                   # 依赖导入
├── services/                 # 业务服务
│   ├── news/
│   ├── user/
│   └── translation/
├── shared/                   # 共享模块
│   ├── types.ts
│   ├── db.ts
│   └── utils.ts
└── tests/                    # 测试文件
    ├── api/
    ├── unit/
    └── integration/
```

### 类型定义

1. **使用严格的类型定义**
   ```typescript
   // 定义完整的接口
   export interface NewsArticle {
     readonly id: string;
     readonly title: string;
     readonly content: string;
     readonly publishedAt: Date;
     readonly category: NewsCategory;
     readonly readCount: number;
     readonly tags: readonly string[];
   }

   export type NewsCategory = 
     | 'news' 
     | 'transfer' 
     | 'match' 
     | 'analysis';
   ```

2. **使用泛型提高复用性**
   ```typescript
   export interface ApiResponse<T> {
     readonly success: boolean;
     readonly data?: T;
     readonly error?: ApiError;
     readonly meta?: ResponseMeta;
   }

   export class DatabaseService<T> {
     async findById(id: string): Promise<T | null> {
       // 实现代码...
     }
     
     async create(entity: Omit<T, 'id'>): Promise<T> {
       // 实现代码...
     }
   }
   ```

### 错误处理

1. **自定义错误类**
   ```typescript
   export class ServiceError extends Error {
     constructor(
       public readonly code: string,
       message: string,
       public readonly statusCode: number = 500,
       public readonly details?: unknown
     ) {
       super(message);
       this.name = 'ServiceError';
     }
   }

   export class ValidationError extends ServiceError {
     constructor(message: string, details?: unknown) {
       super('VALIDATION_ERROR', message, 400, details);
     }
   }
   ```

2. **统一错误处理中间件**
   ```typescript
   export async function errorHandler(ctx: Context, next: () => Promise<unknown>) {
     try {
       await next();
     } catch (error) {
       console.error('API Error:', error);
       
       if (error instanceof ServiceError) {
         ctx.response.status = error.statusCode;
         ctx.response.body = {
           success: false,
           error: {
             code: error.code,
             message: error.message,
             details: error.details,
           },
           meta: {
             timestamp: new Date().toISOString(),
           },
         };
       } else {
         // 处理未预期的错误
         ctx.response.status = 500;
         ctx.response.body = {
           success: false,
           error: {
             code: 'INTERNAL_ERROR',
             message: '服务器内部错误',
           },
         };
       }
     }
   }
   ```

### API 路由设计

1. **RESTful 设计原则**
   ```typescript
   // 资源路由设计
   router.get('/api/v1/news', getNewsList);           // 获取列表
   router.get('/api/v1/news/:id', getNewsDetail);     // 获取详情
   router.post('/api/v1/news', createNews);           // 创建资源
   router.put('/api/v1/news/:id', updateNews);        // 完整更新
   router.patch('/api/v1/news/:id', patchNews);       // 部分更新
   router.delete('/api/v1/news/:id', deleteNews);     // 删除资源
   ```

2. **参数验证**
   ```typescript
   import { z } from 'https://deno.land/x/zod@v3.22.4/mod.ts';

   const newsQuerySchema = z.object({
     page: z.number().int().positive().default(1),
     limit: z.number().int().min(1).max(100).default(20),
     category: z.enum(['news', 'transfer', 'match']).optional(),
     language: z.string().length(2).optional(),
   });

   export async function getNewsList(ctx: Context) {
     try {
       const query = newsQuerySchema.parse({
         page: parseInt(ctx.request.url.searchParams.get('page') ?? '1'),
         limit: parseInt(ctx.request.url.searchParams.get('limit') ?? '20'),
         category: ctx.request.url.searchParams.get('category'),
         language: ctx.request.url.searchParams.get('language'),
       });

       // 使用验证后的参数
       const result = await newsService.getNews(query);
       
       ctx.response.body = {
         success: true,
         data: result.data,
         meta: {
           page: query.page,
           limit: query.limit,
           total: result.total,
           timestamp: new Date().toISOString(),
         },
       };
     } catch (error) {
       if (error instanceof z.ZodError) {
         throw new ValidationError('请求参数无效', error.errors);
       }
       throw error;
     }
   }
   ```

### 数据库操作

1. **使用事务保证数据一致性**
   ```typescript
   export class NewsService {
     constructor(private db: DatabaseManager) {}

     async createNewsWithTags(
       newsData: Omit<NewsArticle, 'id' | 'createdAt'>,
       tags: string[]
     ): Promise<NewsArticle> {
       const client = await this.db.getClient();
       
       try {
         await client.queryObject('BEGIN');
         
         // 创建新闻记录
         const newsResult = await client.queryObject<NewsArticle>`
           INSERT INTO news_articles (title, content, category, published_at)
           VALUES (${newsData.title}, ${newsData.content}, ${newsData.category}, ${newsData.publishedAt})
           RETURNING *
         `;
         
         const news = newsResult.rows[0];
         
         // 创建标签关联
         if (tags.length > 0) {
           await client.queryObject`
             INSERT INTO news_tags (news_id, tag)
             VALUES ${tags.map(tag => `(${news.id}, ${tag})`).join(', ')}
           `;
         }
         
         await client.queryObject('COMMIT');
         return news;
         
       } catch (error) {
         await client.queryObject('ROLLBACK');
         throw error;
       } finally {
         client.release();
       }
     }
   }
   ```

## 性能优化规范

### Flutter 性能优化

1. **列表优化**
   ```dart
   // 使用 ListView.builder 代替 ListView
   ListView.builder(
     itemCount: newsList.length,
     itemBuilder: (context, index) {
       return NewsCard(news: newsList[index]);
     },
   );
   
   // 对于复杂列表使用 flutter_staggered_grid_view
   MasonryGridView.builder(
     gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
       crossAxisCount: 2,
     ),
     itemBuilder: (context, index) => NewsCard(news: newsList[index]),
   );
   ```

2. **图片优化**
   ```dart
   // 使用缓存网络图片
   CachedNetworkImage(
     imageUrl: news.imageUrl ?? '',
     placeholder: (context, url) => const LoadingShimmer(),
     errorWidget: (context, url, error) => const Icon(Icons.error),
     memCacheWidth: 300, // 限制内存缓存尺寸
   );
   ```

### 后端性能优化

1. **数据库查询优化**
   ```typescript
   // 使用索引提高查询性能
   const newsQuery = `
     SELECT n.*, COUNT(c.id) as comment_count
     FROM news_articles n
     LEFT JOIN comments c ON n.id = c.news_id
     WHERE n.published_at >= $1
       AND n.category = $2
     GROUP BY n.id
     ORDER BY n.published_at DESC
     LIMIT $3 OFFSET $4
   `;
   
   // 使用预编译语句
   const preparedStatement = await client.prepareQuery(newsQuery);
   ```

2. **缓存策略**
   ```typescript
   export class CacheService {
     private redis: RedisClient;
     
     async get<T>(key: string): Promise<T | null> {
       const cached = await this.redis.get(key);
       return cached ? JSON.parse(cached) : null;
     }
     
     async set<T>(key: string, value: T, ttl = 3600): Promise<void> {
       await this.redis.setex(key, ttl, JSON.stringify(value));
     }
     
     async getOrSet<T>(
       key: string,
       fetchFn: () => Promise<T>,
       ttl = 3600
     ): Promise<T> {
       let cached = await this.get<T>(key);
       
       if (!cached) {
         cached = await fetchFn();
         await this.set(key, cached, ttl);
       }
       
       return cached;
     }
   }
   ```

## 代码审查清单

### 提交前检查

- [ ] 代码遵循命名规范
- [ ] 添加了适当的注释
- [ ] 包含必要的错误处理
- [ ] 编写了相应的测试
- [ ] 通过了所有现有测试
- [ ] 代码格式化正确
- [ ] 没有遗留的 console.log 或 print 语句
- [ ] 性能影响已经评估

### 审查重点

1. **功能正确性**
   - 业务逻辑是否正确
   - 边界条件处理
   - 异常情况处理

2. **代码质量**
   - 代码可读性
   - 逻辑清晰性
   - 复用性设计

3. **性能考虑**
   - 是否有性能瓶颈
   - 内存使用是否合理
   - 网络请求优化

4. **安全性**
   - 输入验证
   - SQL注入防护
   - 敏感信息保护

遵循这些规范可以确保球探社项目代码的高质量和可维护性。