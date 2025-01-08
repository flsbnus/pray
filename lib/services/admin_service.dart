// lib/services/admin_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static final String adminEmail = "ad@n.com"; // 관리자 이메일 설정

  static bool isAdmin(User? user) {
    return user?.email == adminEmail;
  }
}