import 'package:flutter_riverpod/flutter_riverpod.dart';

// 认证服务Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  bool _isLoggedIn = false;
  
  bool get isLoggedIn => _isLoggedIn;
  
  Future<bool> login(String email, String password) async {
    // TODO: 实现实际的登录逻辑
    await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
    _isLoggedIn = true;
    return true;
  }
  
  Future<void> logout() async {
    // TODO: 实现实际的登出逻辑
    _isLoggedIn = false;
  }
  
  Future<bool> register(String username, String email, String password) async {
    // TODO: 实现实际的注册逻辑
    await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
    _isLoggedIn = true;
    return true;
  }
} 