import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProgressService {
  
  // قائمة المجموعات التي تحتوي على مستندات الـ PO الفردية (تجنبنا وضع '0001' هنا)
  static final List<String> dataCollections = [
    'kasim_projects',
    'algof_projects',
    'projects', // سيبحث فيها عن مستند الـ PO مباشرة وليس 0001
  ];

  // دالة جلب تفاصيل المشروع بناءً على الـ PO والتاريخ المختار
  static Future<Map<String, String>> fetchProjectDataByPO(String projectPO, DateTime date) async {
    try {
      // تنسيق التاريخ للبحث داخل الـ data_date
      final formattedDate = DateFormat('EEE MMM dd yyyy').format(date);

      DocumentSnapshot? matchedDoc;
      String? foundInCollection;

      // البحث عن مستند الـ PO داخل المجموعات المتاحة
      for (String collectionName in dataCollections) {
        // تخطي مستند 0001 تماماً إذا كنا نبحث داخل مجموعة projects
        if (collectionName == 'projects' && projectPO == '0001') continue;

        final progressPOCollection = FirebaseFirestore.instance
            .collection(collectionName)
            .doc(projectPO)
            .collection('progress');

        final snapshotPO = await progressPOCollection.get();

        for (var doc in snapshotPO.docs) {
          final data = doc.data();
          final dataDate = data['data_date']?.toString() ?? "";
          if (dataDate.contains(formattedDate)) {
            matchedDoc = doc;
            foundInCollection = collectionName;
            break;
          }
        }
        if (matchedDoc != null) break; // إذا وجدنا التاريخ المطلوب نوقف البحث
      }

      if (matchedDoc == null) return {};

      final data = matchedDoc.data() as Map<String, dynamic>;

      return {
        "plannedPercent": (data["planned_percentage"] ?? "0").toString(),
        "actualPercent": (data["monthly_actual"] ?? "0").toString(),
        "elapsedPercent": (data["elapsed_percentage"] ?? "0").toString(),
        "startDate": (data["project_start"] ?? "غير محدد").toString(),
        "endDate": (data["project_finish"] ?? "غير محدد").toString(),
        "activeCollection": foundInCollection ?? "", // لتسهيل عملية التحديث لاحقاً
      };
    } catch (e) {
      print("❌ خطأ أثناء جلب بيانات المشروع عبر الـ PO: $e");
      return {};
    }
  }
}