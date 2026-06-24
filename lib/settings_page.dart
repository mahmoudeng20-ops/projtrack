import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
// 🔥 استيراد ملف الـ main للوصول إلى كائن الـ appState للتحكم الشامل
import 'main.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // جلب بيانات المستخدم الحالي من الفايربيز
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // دالة فتح تطبيق الإيميل لإرسال الملاحظات
  Future<void> _sendFeedbackEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'admin@pm-systems.xyz', // تم ربطه بالدومين الخاص بك بنجاح
      query: encodeQueryParameters(<String, String>{
        'subject': '🎯 ملاحظات واقتراحات حول تطبيق نسب الإنجاز',
        'body': 'السلام عليكم ورحمة الله وبركاته،\n\nلدي الملاحظة التالية:\n- '
      }),
    );

    try {
      // 🔥 استخدام externalApplication لضمان استجابة نظام التشغيل لروابط mailto
      if (await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication)) {
        print("تم فتح تطبيق البريد بنجاح");
      } else {
        throw 'Could not launch $emailLaunchUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ تعذر فتح تطبيق البريد الإلكتروني: $e")),
        );
      }
    }
  }

  // دالة حذف الحساب مع تأكيد
  Future<void> _deleteAccount() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String currentLangCode = appState.locale.languageCode;
    bool isArabic = currentLangCode == 'ar';

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? "تأكيد حذف الحساب" : "Confirm Delete Account"),
        content: Text(isArabic
            ? "هل أنت متأكد؟ سيتم حذف حسابك نهائياً ولا يمكن التراجع."
            : "Are you sure? Your account will be permanently deleted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? "إلغاء" : "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isArabic ? "نعم، احذف" : "Yes, delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await user.delete();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // طلب إعادة تسجيل الدخول
        String? password = await _showReauthDialog();
        if (password == null) return;

        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        await user.delete();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ فشل الحذف: ${e.message}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ خطأ غير متوقع: $e")),
        );
      }
    }
  }

  // نافذة إعادة تسجيل الدخول بكلمة المرور
  Future<String?> _showReauthDialog() {
    String langCode = appState.locale.languageCode;
    bool isArabic = langCode == 'ar';
    TextEditingController passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? "إعادة تسجيل الدخول" : "Re-authentication"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: isArabic ? "كلمة المرور" : "Password",
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? "إلغاء" : "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, passwordController.text),
            child: Text(isArabic ? "تأكيد" : "Confirm"),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لتنسيق نصوص الإيميل
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 1. فحص حالة الثيم الحالية للتطبيق ديناميكياً
    bool isDarkMode = appState.themeMode == ThemeMode.dark;

    // 🔥 2. فحص لغة التطبيق الحالية المسجلة بالنظام
    String currentLangCode = appState.locale.languageCode; 
    bool isArabic = currentLangCode == 'ar';

    // ألوان ديناميكية متوافقة مع الوضع الليلي لمنع مشاكل اختفاء النصوص
    Color titleColor = isDarkMode ? Colors.blue.shade300 : Colors.blue.shade900;
    Color subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    Color avatarBgColor = isDarkMode ? Colors.blue.shade900 : Colors.blue.shade100;
    Color avatarIconColor = isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? "إعدادات التطبيق" : "App Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 👤 قسم معلومات الحساب
          _buildSectionTitle(isArabic ? "معلومات الحساب" : "Account Information", isArabic, titleColor),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: avatarBgColor,
                    child: Icon(Icons.person, size: 35, color: avatarIconColor),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.displayName ?? (isArabic ? "مهندس المشروع" : "Project Engineer"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          currentUser?.email ?? (isArabic ? "لا يوجد بريد إلكتروني مسجل" : "No email registered"),
                          style: TextStyle(fontSize: 14, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // ⚙️ قسم تفضيلات التطبيق
          _buildSectionTitle(isArabic ? "تفضيلات النظام" : "System Preferences", isArabic, titleColor),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                // ميزة الوضع الليلي والنهاري
                ListTile(
                  leading: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: isDarkMode ? Colors.amber : Colors.orange,
                  ),
                  title: Text(isArabic ? "مظهر التطبيق" : "App Theme"),
                  subtitle: Text(
                    isArabic 
                      ? (isDarkMode ? "الوضع الليلي مفعّل" : "الوضع النهاري مفعّل")
                      : (isDarkMode ? "Dark Mode Enabled" : "Light Mode Enabled")
                  ),
                  trailing: Switch(
                    value: isDarkMode,
                    activeColor: Colors.blue,
                    onChanged: (value) async {
                      await appState.changeTheme(value);
                      setState(() {});
                    },
                  ),
                ),
                const Divider(height: 1),
                
                // ميزة اختيار لغة التطبيق
                ListTile(
                  leading: const Icon(Icons.language, color: Colors.blue),
                  title: Text(isArabic ? "لغة التطبيق" : "Language"),
                  subtitle: Text(isArabic ? "اللغة الحالية: العربية" : "Current Language: English"),
                  trailing: DropdownButton<String>(
                    value: currentLangCode, 
                    underline: const SizedBox(), 
                    dropdownColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
                    items: [
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text(isArabic ? "العربية" : "Arabic"),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(isArabic ? "English" : "English"),
                      ),
                    ],
                    onChanged: (newLangCode) async {
                      if (newLangCode != null) {
                        await appState.changeLanguage(newLangCode);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // ✉️ قسم الدعم والملاحظات
          _buildSectionTitle(isArabic ? "الدعم والتواصل" : "Support & Contact", isArabic, titleColor),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined, color: Colors.teal),
              title: Text(isArabic ? "إرسال ملاحظات واقتراحات" : "Send Feedback & Requests"),
              subtitle: Text(isArabic ? "سيتم إرسالها مباشرة إلى الإدارة الميدانية" : "Will be sent directly to project admin"),
              trailing: Icon(isArabic ? Icons.arrow_back_ios : Icons.arrow_forward_ios, size: 16),
              onTap: _sendFeedbackEmail,
            ),
          ),
          const SizedBox(height: 20),

          // 🗑️ زر حذف الحساب
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                isArabic ? "حذف الحساب" : "Delete Account",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 🚪 زر تسجيل الخروج
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: Text(
                isArabic ? "تسجيل الخروج" : "Logout", 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // عنصر مساعد لبناء عناوين الأقسام بشكل منسق مع مراعاة اتجاه اللغة ولونها ديناميكياً
  Widget _buildSectionTitle(String title, bool isArabic, Color textColor) {
    return Padding(
      padding: EdgeInsets.only(
        right: isArabic ? 8.0 : 0.0, 
        left: isArabic ? 0.0 : 8.0, 
        bottom: 8.0
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold, 
          color: textColor
        ),
      ),
    );
  }
}