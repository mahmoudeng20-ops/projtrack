import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'progress_page.dart';

late MyAppState appState;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  @override
  void initState() {
    super.initState();
    appState = this; 
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    final langCode = prefs.getString('app_language') ?? 'ar';
    
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _locale = Locale(langCode);
    });
  }

  Future<void> changeTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Project Progress',
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), 
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.white70),
        ),
      ),
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/progress': (context) => const ProgressPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLoginAndLoadCredentials();
  }

  Future<void> _checkAutoLoginAndLoadCredentials() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    
    final savedUsername = prefs.getString('saved_user_name');
    final savedEmail = prefs.getString('saved_user_email');
    final savedPassword = prefs.getString('saved_user_password');

    if (mounted) {
      setState(() {
        if (savedUsername != null) _usernameController.text = savedUsername;
        if (savedEmail != null) _emailController.text = savedEmail;
        if (savedPassword != null) _passwordController.text = savedPassword;
      });
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('app_users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.get('status') == 'approved') {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/progress');
            return;
          }
        } else {
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) {
        // خطأ صامت في الخلفية أثناء الدخول التلقائي
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveCredentials(String username, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_user_name', username);
    await prefs.setString('saved_user_email', email);
    await prefs.setString('saved_user_password', password);
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (email.isEmpty || !_isValidEmail(email)) {
      _showSnackBar(isArabic ? "⚠️ يرجى كتابة بريدك الإلكتروني بشكل صحيح أولاً لإرسال رابط التعيين." : "⚠️ Please enter a valid email to send reset link.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar(isArabic ? "📧 تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني بنجاح." : "📧 Password reset link sent to your email successfully.", Colors.green);
    } on FirebaseAuthException catch (e) {
      String message = isArabic ? "❌ تعذر إرسال البريد: ${e.message}" : "❌ Failed: ${e.message}";
      if (e.code == 'user-not-found') {
        message = isArabic ? "❌ هذا البريد الإلكتروني غير مسجل بالنظام." : "❌ This email is not registered.";
      } else if (e.code == 'invalid-email') {
        message = isArabic ? "❌ صيغة البريد الإلكتروني غير صحيحة." : "❌ Invalid email format.";
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar("❌ Error: $e", Colors.red);
    } finally { 
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String? uid = userCredential.user?.uid;

      if (uid != null) {
        await userCredential.user?.updateDisplayName(_usernameController.text.trim());

        await FirebaseFirestore.instance.collection('app_users').doc(uid).set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'status': 'pending', 
          'created_at': FieldValue.serverTimestamp(),
        });

        _showSnackBar(isArabic ? "✅ تم تسجيل طلبك! بانتظار موافقة الإدارة لتفعيل الحساب." : "✅ Request registered! Awaiting admin approval to activate account.", Colors.orange);
        
        await _saveCredentials(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim()
        );
        
        await FirebaseAuth.instance.signOut();
      }

    } on FirebaseAuthException catch (e) {
      String message = isArabic ? "❌ خطأ أثناء التسجيل: ${e.message}" : "❌ Registration error: ${e.message}";
      if (e.code == 'weak-password') {
        message = isArabic ? "❌ كلمة المرور ضعيفة جداً (يجب أن لا تقل عن 6 أحرف)." : "❌ Weak password (must be at least 6 characters).";
      } else if (e.code == 'email-already-in-use') {
        message = isArabic ? "❌ هذا البريد الإلكتروني مستخدم بالفعل." : "❌ This email is already in use.";
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar("❌ Error: $e", Colors.red);
    } finally { 
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    setState(() => _isLoading = true);
    try {
      // إرسال البيانات مع التأكد التام من عمل .trim() لإزالة أي مسافات زائدة ومخفية
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(), // تم إضافة الـ trim هنا لحمايتها من الفراغات المفاجئة
      );

      String? uid = userCredential.user?.uid;

      if (uid != null) {
        // محاولة جلب وثيقة المستخدم من Firestore لفحص حالة الحساب (approved)
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('app_users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          String status = userDoc.get('status') ?? 'pending';
          String username = userDoc.get('username') ?? '';

          if (status == 'approved') {
            _showSnackBar(isArabic ? "✅ أهلاً بك! تم تسجيل الدخول بنجاح" : "✅ Welcome! Logged in successfully", Colors.green);
            
            await _saveCredentials(
              username,
              _emailController.text.trim(),
              _passwordController.text.trim()
            );
            
            if (mounted) Navigator.pushReplacementNamed(context, '/progress');
          } else {
            // الحساب موجود ولكن حالته pending (لم يتم تفعيله بعد من لوحة التحكم أو قواعد Firestore)
            _showSnackBar(isArabic ? "⏳ عذراً، حسابك لا يزال قيد المراجعة والموافقة من الإدارة." : "⏳ Sorry, your account is still pending admin approval.", Colors.amber.shade800);
            
            await _saveCredentials(
              username,
              _emailController.text.trim(),
              _passwordController.text.trim()
            );
            
            await FirebaseAuth.instance.signOut(); 
          }
        } else {
          // الحساب مسجل بـ Auth ولكن لا توجد له وثيقة بداخل كولكشن app_users
          _showSnackBar(isArabic ? "❌ الحساب مسجل بالـ Auth ولكن لم يتم العثور على بيانات الصلاحيات الخاصة بك في Firestore." : "❌ User authorization document not found in Firestore.", Colors.red);
          await FirebaseAuth.instance.signOut();
        }
      }

    } on FirebaseAuthException catch (e) {
      // 🔥 تعديل جوهري: إظهار كود الخطأ الحقيقي القادم من الخادم بدل النص الثابت
      String message = isArabic ? "❌ خطأ: " : "❌ Error: ";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message += isArabic ? "البريد الإلكتروني أو كلمة المرور غير صحيحة." : "Incorrect email or password.";
      } else if (e.code == 'network-request-failed') {
        message += isArabic ? "فشل الاتصال بالإنترنت. تحقق من الشبكة." : "Network error. Please check internet connection.";
      } else {
        message += "${e.message} (${e.code})"; // يطبع تفصيل الخطأ بوضوح
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      // يمسك أي أخطاء أخرى مثل مشاكل الـ Rules الخاصة بـ Firestore لمنع جلب البيانات
      _showSnackBar(isArabic ? "❌ خطأ غير متوقع: $e" : "❌ Unexpected Error: $e", Colors.red);
    } finally { 
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)), 
        backgroundColor: color,
        duration: const Duration(seconds: 5), // زيادة الوقت قليلاً لقراءة الخطأ التفصيلي
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? "تسجيل الدخول للنظام" : "System Login"),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading 
        ? const CircularProgressIndicator() 
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_person, size: 80, color: Colors.blue),
                const SizedBox(height: 30),
                
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: isArabic ? "اسم المستخدم (مطلوب عند التسجيل الجديد)" : "Username (Required for new registration)",
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isArabic ? "البريد الإلكتروني" : "Email Address",
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return isArabic ? "يرجى إدخال البريد الإلكتروني" : "Please enter email address";
                    }
                    if (!_isValidEmail(value.trim())) {
                      return isArabic ? "صيغة البريد الإلكتروني غير صالحة" : "Invalid email format";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  decoration: InputDecoration(
                    labelText: isArabic ? "كلمة المرور" : "Password",
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordObscured = !_isPasswordObscured;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isArabic ? "يرجى إدخال كلمة المرور" : "Please enter password";
                    }
                    return null;
                  },
                ),
                
                Align(
                  alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: Text(
                      isArabic ? "نسيت كلمة المرور؟" : "Forgot Password?",
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed: _loginUser,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(isArabic ? "تسجيل الدخول" : "Login", style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                
                OutlinedButton(
                  onPressed: () {
                    if (_usernameController.text.trim().isEmpty) {
                      _showSnackBar(isArabic ? "⚠️ يرجى كتابة اسم المستخدم أولاً لإنشاء حساب جديد" : "⚠️ Please enter username first to register.", Colors.red);
                      return;
                    }
                    _registerUser();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.blue),
                  ),
                  child: Text(isArabic ? "تسجيل مستخدم جديد" : "Register New User", style: const TextStyle(fontSize: 16, color: Colors.blue)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}