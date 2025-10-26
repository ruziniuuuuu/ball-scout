import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

// 认证状态Provider
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AuthStateNotifier(apiService);
});

// 认证服务Provider (保持向后兼容)
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

// 认证状态
class AuthState {
  final bool isLoggedIn;
  final bool isGuest;
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isGuest = false,
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get hasSession => isLoggedIn || isGuest;

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isGuest,
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isGuest: isGuest ?? this.isGuest,
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 认证状态通知器
class AuthStateNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthStateNotifier(this._apiService) : super(const AuthState()) {
    _loadAuthState();
  }

  // 加载保存的认证状态
  Future<void> _loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userData = prefs.getString(_userKey);

      if (token != null && userData != null) {
        _apiService.setAuthToken(token);
        // TODO: 解析用户数据，这里简化处理
        state = state.copyWith(
          isLoggedIn: true,
          isGuest: false,
          token: token,
        );
      }
    } catch (_) {}
  }

  // 保存认证状态
  Future<void> _saveAuthState(String token, User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, user.toJson().toString());
    } catch (_) {}
  }

  // 清除认证状态
  Future<void> _clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  // 游客登录
  void continueAsGuest() {
    _apiService.clearAuthToken();
    state = state.copyWith(
      isGuest: true,
      isLoggedIn: false,
      user: null,
      token: null,
      error: null,
      isLoading: false,
    );
  }

  // 登录
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, isGuest: false);

    try {
      final request = LoginRequest(email: email, password: password);
      final response = await _apiService.login(request);

      _apiService.setAuthToken(response.data.token);
      await _saveAuthState(response.data.token, response.data.user);

      state = state.copyWith(
        isLoggedIn: true,
        isGuest: false,
        user: response.data.user,
        token: response.data.token,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // 注册
  Future<bool> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, isGuest: false);

    try {
      final request = RegisterRequest(
        username: username,
        email: email,
        password: password,
      );
      final response = await _apiService.register(request);

      _apiService.setAuthToken(response.data.token);
      await _saveAuthState(response.data.token, response.data.user);

      state = state.copyWith(
        isLoggedIn: true,
        isGuest: false,
        user: response.data.user,
        token: response.data.token,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // 登出
  Future<void> logout() async {
    _apiService.clearAuthToken();
    await _clearAuthState();

    state = const AuthState();
  }

  // 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// 兼容性认证服务
class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  AuthState get _state => _ref.read(authStateProvider);

  bool get isLoggedIn => _state.isLoggedIn;
  bool get isGuest => _state.isGuest;
  bool get hasSession => _state.hasSession;
  User? get user => _state.user;
  String? get token => _state.token;

  Future<bool> login(String email, String password) async {
    return await _ref.read(authStateProvider.notifier).login(email, password);
  }

  Future<bool> register(String username, String email, String password) async {
    return await _ref
        .read(authStateProvider.notifier)
        .register(username, email, password);
  }

  Future<void> logout() async {
    await _ref.read(authStateProvider.notifier).logout();
  }

  void continueAsGuest() {
    _ref.read(authStateProvider.notifier).continueAsGuest();
  }

  void clearError() {
    _ref.read(authStateProvider.notifier).clearError();
  }
}
