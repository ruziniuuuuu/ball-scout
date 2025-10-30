import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // 监听认证状态变化
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isLoggedIn) {
        context.go('/');
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
        // 清除错误状态
        Future.microtask(() {
          ref.read(authStateProvider.notifier).clearError();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              // Logo和标题
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '球探社',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '发现真正的足球世界',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.mediumGray,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ),

              // 登录表单
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Tab切换 - 现代简约设计
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgGray,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: AppTheme.primaryGreen,
                        unselectedLabelColor: AppTheme.mediumGray,
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        tabs: const [
                          Tab(text: '登录'),
                          Tab(text: '注册'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 表单内容
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 登录表单
                          _buildLoginForm(authState),
                          // 注册表单
                          _buildRegisterForm(authState),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 游客模式按钮 - 现代简约设计
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(authStateProvider.notifier)
                              .continueAsGuest();
                          context.go('/');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(
                            color: AppTheme.primaryGreen,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '以游客身份浏览',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: AppTheme.primaryGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 邮箱输入框
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入您的邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入邮箱';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // 密码输入框
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入您的密码',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.mediumGray,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入密码';
              }
              if (value.length < 6) {
                return '密码至少6位';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // 登录按钮 - 现代简约设计
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '登录',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthState authState) {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 用户名输入框
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '请输入用户名',
              prefixIcon: Icon(Icons.person_outlined),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入用户名';
              }
              if (value.length < 3) {
                return '用户名至少3位';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // 邮箱输入框
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入您的邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入邮箱';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // 密码输入框
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入您的密码',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.mediumGray,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入密码';
              }
              if (value.length < 6) {
                return '密码至少6位';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // 注册按钮 - 现代简约设计
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '注册',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      await ref.read(authStateProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  Future<void> _handleRegister() async {
    await ref.read(authStateProvider.notifier).register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
  }
}
