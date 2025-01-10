import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'screens/prayer_list_manager_screen.dart';
import 'services/admin_service.dart';
import 'dart:math' show sin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '서울동부청년회 합심기도',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Katuri',
      ),
      home: AuthStateScreen(),
    );
  }
}

class AuthStateScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> _checkProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: _checkProfile(snapshot.data!.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (profileSnapshot.data == true) {
                return HomeScreen();
              }

              return ProfileSetupScreen();
            },
          );
        }

        return AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('서울동부청년회 합심기도'),
          bottom: TabBar(
            tabs: [
              Tab(text: '로그인'),
              Tab(text: '회원가입'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LoginTab(),
            SignUpTab(),
          ],
        ),
      ),
    );
  }
}

class LoginTab extends StatefulWidget {
  @override
  _LoginTabState createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  String email = '';
  String password = '';
  String errorMessage = '';
  bool isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      try {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = _getErrorMessage(e.code);
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '잘못된 비밀번호입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      default:
        return '로그인에 실패했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) =>
                  value?.isEmpty ?? true ? '이메일을 입력하세요' : null,
              onChanged: (value) => email = value,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) =>
                  value?.isEmpty ?? true ? '비밀번호를 입력하세요' : null,
              onChanged: (value) => password = value,
            ),
            if (errorMessage.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _login,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('로그인'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpTab extends StatefulWidget {
  @override
  _SignUpTabState createState() => _SignUpTabState();
}

class _SignUpTabState extends State<SignUpTab> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  String email = '';
  String password = '';
  String confirmPassword = '';
  String errorMessage = '';
  bool isLoading = false;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (password != confirmPassword) {
        setState(() {
          errorMessage = '비밀번호가 일치하지 않습니다.';
        });
        return;
      }

      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      try {
        await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = _getErrorMessage(e.code);
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다.';
      default:
        return '회원가입에 실패했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '이메일을 입력하세요';
                }
                if (!value!.contains('@')) {
                  return '올바른 이메일 형식이 아닙니다';
                }
                return null;
              },
              onChanged: (value) => email = value,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '비밀번호를 입력하세요';
                }
                if (value!.length < 6) {
                  return '비밀번호는 6자 이상이어야 합니다';
                }
                return null;
              },
              onChanged: (value) => password = value,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '비밀번호를 다시 입력하세요';
                }
                if (value != password) {
                  return '비밀번호가 일치하지 않습니다';
                }
                return null;
              },
              onChanged: (value) => confirmPassword = value,
            ),
            if (errorMessage.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _signUp,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('회원가입'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String name = '';
  String gender = '';
  String zone = '';
  String department = '';
  bool isLoading = false;

  final List<String> zones = [
    '11',
    '12',
    '13',
    '21',
    '22',
    '23',
    '31',
    '32',
    '33',
    '41',
    '42',
    '43',
  ];

  final List<String> departments = [
    '소망부',
    '사랑부',
    '기타',
  ];

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate() && _validateFields()) {
      setState(() {
        isLoading = true;
      });

      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'name': name,
            'gender': gender,
            'zone': zone,
            'department': department,
            'createdAt': FieldValue.serverTimestamp(),
            'totalPrayerTime': 0,
            'email': user.email,
          });

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 저장 중 오류가 발생했습니다.')),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _validateFields() {
    String error = '';

    if (gender.isEmpty) {
      error = '형제/자매를 선택해주세요';
    } else if (zone.isEmpty) {
      error = '구역을 선택해주세요';
    } else if (department.isEmpty) {
      error = '청년회 부서를 선택해주세요';
    }

    if (error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('프로필 설정'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '환영합니다!\n기도 생활을 시작하기 전에\n프로필을 설정해 주세요.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              // 이름 입력
              TextFormField(
                decoration: InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이름을 입력해주세요';
                  }
                  return null;
                },
                onChanged: (value) => name = value,
              ),
              SizedBox(height: 24),

              // 형제/자매 선택
              Text(
                '형제/자매 선택',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('형제'),
                      value: '형제',
                      groupValue: gender,
                      onChanged: (value) {
                        setState(() {
                          gender = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('자매'),
                      value: '자매',
                      groupValue: gender,
                      onChanged: (value) {
                        setState(() {
                          gender = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // 구역 선택
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: '구역 선택',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
                value: zone.isEmpty ? null : zone,
                items: zones.map((String zone) {
                  return DropdownMenuItem(
                    value: zone,
                    child: Text('$zone구역'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    zone = value!;
                  });
                },
              ),
              SizedBox(height: 24),

              // 청년회 부서 선택
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: '청년회 부서 선택',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                value: department.isEmpty ? null : department,
                items: departments.map((String department) {
                  return DropdownMenuItem(
                    value: department,
                    child: Text(department),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    department = value!;
                  });
                },
              ),
              SizedBox(height: 32),

              // 저장 버튼
              ElevatedButton(
                onPressed: isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '시작하기',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 열기 효과를 위한 CustomPainter
class HeatWavePainter extends CustomPainter {
  final double progress;
  final Color baseColor;

  HeatWavePainter({
    required this.progress,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor.withOpacity(0.1 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final wave = Path();
    var y = size.height * 0.5;

    for (var x = 0.0; x < size.width; x += 20) {
      y += sin(x * 0.03 + (progress * 2)) * 5;
      if (x == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }

    canvas.drawPath(wave, paint);
  }

  @override
  bool shouldRepaint(HeatWavePainter oldDelegate) =>
      progress != oldDelegate.progress || baseColor != oldDelegate.baseColor;
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool isPraying = false;
  DateTime? startTime;
  Timer? timer;
  Duration duration = Duration.zero;
  String? currentPrayerDocId;
  late ConfettiController _confettiController;

  void _showPrayerTogether() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return PrayerTogetherModal();
        },
      ),
    );
  }

  final double targetMinutes = 9182;
  final List<Color> thermometerColors = [
    Colors.red[200]!,
    Colors.red[300]!,
    Colors.red[400]!,
    Colors.red[500]!,
    Colors.red[600]!,
    Colors.red[700]!,
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 5));
  }

  @override
  void dispose() {
    timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void startPrayer() async {
    final now = DateTime.now();
    final user = _auth.currentUser;

    if (user != null) {
      DocumentReference docRef =
          await _firestore.collection('prayerSessions').add({
        'userId': user.uid,
        'startTime': now,
        'endTime': null,
      });

      setState(() {
        isPraying = true;
        startTime = now;
        currentPrayerDocId = docRef.id;
      });

      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            duration = DateTime.now().difference(startTime!);
          });
        }
      });
    }
  }

  void endPrayer() async {
    final user = _auth.currentUser;

    if (user != null && currentPrayerDocId != null) {
      final now = DateTime.now();

      await _firestore
          .collection('prayerSessions')
          .doc(currentPrayerDocId)
          .update({
        'endTime': now,
        'duration': now.difference(startTime!).inSeconds,
      });

      final userRef = _firestore.collection('users').doc(user.uid);
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentTotal = userDoc.data()?['totalPrayerTime'] ?? 0;
        transaction.update(userRef, {
          'totalPrayerTime':
              currentTotal + now.difference(startTime!).inSeconds,
        });
      });

      timer?.cancel();
      setState(() {
        isPraying = false;
        startTime = null;
        duration = Duration.zero;
        currentPrayerDocId = null;
      });
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget _buildThermometer(double totalMinutes) {
    double progress = totalMinutes / targetMinutes;
    int level = (progress * 5).floor();
    bool isComplete = totalMinutes >= targetMinutes;

    // 프로그레스에 따른 색상 및 효과 강도 계산
    final heatIntensity = progress.clamp(0.0, 1.0);

    // 프로그레스에 따른 색상 변화
    final mainColor = Color.lerp(
        Colors.red.shade400, Colors.deepOrange.shade700, heatIntensity)!;

    if (isComplete) {
      _confettiController.play();
    } else {
      _confettiController.stop();
    }

    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 배경 열기 효과
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2 + (heatIntensity * 0.3),
                  colors: [
                    mainColor.withOpacity(0.15 + (heatIntensity * 0.1)),
                    Colors.transparent,
                  ],
                  stops: [0.2, 1.0],
                ),
              ),
            ),
            // 추가적인 열기 효과 (프로그레스가 높을 때)
            if (progress > 0.5)
              Positioned.fill(
                child: CustomPaint(
                  painter: HeatWavePainter(
                    progress: heatIntensity,
                    baseColor: mainColor,
                  ),
                ),
              ),
            Center(
              child: Container(
                width: screenWidth * 0.95, // 화면 너비의 95%로 설정
                padding: EdgeInsets.symmetric(horizontal: 10),
                height: 400,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 왼쪽 목표 표시
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withOpacity(0.2),
                            blurRadius: 8 + (heatIntensity * 4),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '목표',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '9182분',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 25),
                    // 온도계 본체
                    Container(
                      width: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 300,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.black87,
                                    width: 2.5,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(25),
                                    topRight: Radius.circular(25),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: mainColor.withOpacity(0.3),
                                      blurRadius: 10 + (heatIntensity * 5),
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    // 수은주
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 800),
                                      curve: Curves.easeInOut,
                                      height: 280 * progress.clamp(0.0, 1.0),
                                      width: 35,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            mainColor,
                                            Color.lerp(
                                                mainColor, Colors.white, 0.3)!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: [
                                          BoxShadow(
                                            color: mainColor.withOpacity(
                                                0.3 + (heatIntensity * 0.2)),
                                            blurRadius: 8 + (heatIntensity * 4),
                                            offset: Offset(0, -2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 열기 효과
                                    if (progress > 0.7)
                                      Positioned(
                                        top: 0,
                                        child: Container(
                                          width: 35,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                mainColor.withOpacity(0.3),
                                                mainColor.withOpacity(0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // 온도계 하단 구
                              Container(
                                width: 85,
                                height: 85,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      mainColor,
                                      Color.lerp(
                                          mainColor, Colors.red.shade800, 0.3)!,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black87,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: mainColor.withOpacity(
                                          0.3 + (heatIntensity * 0.2)),
                                      blurRadius: 12 + (heatIntensity * 8),
                                      spreadRadius: heatIntensity * 2,
                                      offset: Offset(3, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${totalMinutes.toInt()}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 2,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // 눈금 표시
                          Positioned(
                            left: 53,
                            top: 0,
                            bottom: 92,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(10, (index) {
                                final value = index == 0
                                    ? 9182
                                    : index == 9
                                        ? 0
                                        : (9000 - (index * 1000));

                                return Row(
                                  children: [
                                    Container(
                                      width: 15,
                                      height: 1.5,
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '$value',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 25),
                    // 오른쪽 현재값 표시
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withOpacity(0.2),
                            blurRadius: 8 + (heatIntensity * 4),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '현재(누적)',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${totalMinutes.toInt()}분',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 축하 효과
            Positioned.fill(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.2,
                shouldLoop: true,
                colors: const [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.deepOrange,
                  Colors.redAccent,
                ],
              ),
            ),
            if (isComplete)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.yellow.shade300,
                      Colors.yellow.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: mainColor.withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '목표달성!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('서울동부청년회 합심기도'),
        actions: [
          if (AdminService.isAdmin(FirebaseAuth.instance.currentUser))
            IconButton(
              icon: Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrayerListManagerScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('prayerSessions').snapshots(),
              builder: (context, snapshot) {
                //             if (snapshot.hasError) {
                //   return Center(child: Text('Error: ${snapshot.error}'));
                // }

                // if (!snapshot.hasData) {
                //   return Center(child: CircularProgressIndicator());
                // }

                // if (snapshot.data!.docs.isEmpty) {
                //   return Center(child: Text('아직 기도 기록이 없습니다.'));
                // }

                if (snapshot.hasData) {
                  double totalMinutes = 0;
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['duration'] != null) {
                      totalMinutes += data['duration'] / 60;
                    }
                  }
                  return _buildThermometer(totalMinutes);
                }
                return Center(child: CircularProgressIndicator());
              },
            ),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('users')
                  .doc(_auth.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  return Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${userData?['name']} ${userData?['gender']}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${userData?['zone']}구역 / ${userData?['department']}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return CircularProgressIndicator();
              },
            ),
            SizedBox(height: 10),
            Text(
              formatDuration(duration),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 10),
            isPraying
                ? ElevatedButton(
                    onPressed: endPrayer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      '기도 종료',
                      style: TextStyle(fontSize: 20),
                    ),
                  )
                : ElevatedButton(
                    onPressed: startPrayer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      '기도 시작',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
            SizedBox(height: 20),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('users')
                  .doc(_auth.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  final totalSeconds = userData?['totalPrayerTime'] ?? 0;
                  final totalDuration = Duration(seconds: totalSeconds);
                  return Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '총 기도시간: ${formatDuration(totalDuration)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[700],
                      ),
                    ),
                  );
                }
                return SizedBox();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PrayerStatsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart),
                  Text('나의 기도현황'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _showPrayerTogether, // 여기를 수정
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group),
                  Text('함께 기도해요'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: 나의 기도수첩 화면으로 이동
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book),
                  Text('나의 기도수첩'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrayerStatsScreen extends StatefulWidget {
  @override
  _PrayerStatsScreenState createState() => _PrayerStatsScreenState();
}

class _PrayerStatsScreenState extends State<PrayerStatsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('나의 기도현황'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('prayerSessions')
            .where('userId', isEqualTo: _auth.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('아직 기도 기록이 없습니다'),
            );
          }

          // 일별 기도시간 계산
          Map<String, double> dailyStats = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['startTime'] != null && data['duration'] != null) {
              DateTime startTime = (data['startTime'] as Timestamp).toDate();
              String dateKey = DateFormat('MM/dd').format(startTime);

              double minutes = (data['duration'] as num).toDouble() / 60;
              dailyStats[dateKey] = (dailyStats[dateKey] ?? 0) + minutes;
            }
          }

          // 날짜 정렬
          var sortedDates = dailyStats.keys.toList()..sort();

          // 최근 7일 데이터만 사용
          var recentDates = sortedDates.length > 7
              ? sortedDates.sublist(sortedDates.length - 7)
              : sortedDates;

          // 그래프 데이터 생성
          final spots = List<FlSpot>.generate(
            recentDates.length,
            (i) => FlSpot(i.toDouble(), dailyStats[recentDates[i]]!),
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '일일 기도시간 그래프',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          height: 300,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 5,
                                verticalInterval: 1,
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt();
                                      if (index >= 0 &&
                                          index < recentDates.length) {
                                        return Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            recentDates[index],
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: Text(
                                          '${value.toInt()}분',
                                          style: TextStyle(fontSize: 12),
                                          textAlign: TextAlign.right,
                                        ),
                                      );
                                    },
                                    interval: 5,
                                    reservedSize: 40, // Y축 레이블을 위한 공간 확보
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.blue,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blue.withOpacity(0.2),
                                  ),
                                ),
                              ],
                              minY: 0,
                              maxY: ((dailyStats.values.reduce(
                                                      (a, b) => a > b ? a : b) *
                                                  1.2)
                                              .roundToDouble() /
                                          5)
                                      .ceil() *
                                  5, // 5의 배수로 반올림
                              lineTouchData: LineTouchData(
                                getTouchedSpotIndicator:
                                    (LineChartBarData barData,
                                        List<int> spotIndexes) {
                                  return spotIndexes.map((spotIndex) {
                                    return TouchedSpotIndicatorData(
                                      FlLine(
                                          color: Colors.blue, strokeWidth: 2),
                                      FlDotData(getDotPainter:
                                          (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 6,
                                          color: Colors.blue,
                                          strokeWidth: 2,
                                          strokeColor: Colors.white,
                                        );
                                      }),
                                    );
                                  }).toList();
                                },
                                touchTooltipData: LineTouchTooltipData(
                                  fitInsideHorizontally: true,
                                  tooltipPadding: const EdgeInsets.all(8),
                                  tooltipMargin: 8,
                                  getTooltipItems:
                                      (List<LineBarSpot> touchedSpots) {
                                    return touchedSpots
                                        .map((LineBarSpot touchedSpot) {
                                      final value =
                                          touchedSpot.y.toStringAsFixed(1);
                                      return LineTooltipItem(
                                        '$value분',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                                handleBuiltInTouches: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '통계 요약',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(height: 24),
                        _buildStatRow(
                          '총 기도일수',
                          '${dailyStats.length}일',
                          Icons.calendar_today,
                        ),
                        SizedBox(height: 8),
                        _buildStatRow(
                          '평균 기도시간',
                          '${(dailyStats.values.reduce((a, b) => a + b) / dailyStats.length).toStringAsFixed(1)}분',
                          Icons.access_time,
                        ),
                        SizedBox(height: 8),
                        _buildStatRow(
                          '최대 기도시간',
                          '${dailyStats.values.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}분',
                          Icons.emoji_events,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 16),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

class PrayerTogetherModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Center(
              child: Text(
                '🙏함께 기도해요🙏',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),

            // 기도 제목 리스트
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrayerItem('1. 교회를 위해'),
                _buildPrayerItem('2. 청년회를 위해'),
                _buildPrayerItem('3. 1월 대집회를 위해'),
                _buildPrayerItem('4. 청년집회를 위해'),
                _buildPrayerItem('5. 말씀전하시는 목회자분들 위해'),
                _buildPrayerItem('6. 내 자신이 집회에 꼭 전참할수있게'),
                _buildPrayerItem('7. 내 자신이 담대히 입을 열어 권유할수있게'),
                _buildPrayerItem('8. 기도부탁 명단분들 위해'),
              ],
            ),
            SizedBox(height: 20),

            // 기도부탁 명단 버튼
            Center(
              child: ElevatedButton(
                onPressed: () => _showPrayerList(context),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('기도부탁 명단 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  void _showPrayerList(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // 이미지
                FutureBuilder<String?>(
                  future: FirebaseStorage.instance
                      .ref()
                      .child('prayer_lists')
                      .listAll()
                      .then((result) async {
                    if (result.items.isEmpty) return null;
                    return await result.items.last.getDownloadURL();
                  }),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: CachedNetworkImage(
                        imageUrl: snapshot.data!,
                        placeholder: (context, url) =>
                            Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                            Center(child: Text('이미지를 불러올 수 없습니다')),
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                // 닫기 버튼
                Positioned(
                  top: 40,
                  right: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
