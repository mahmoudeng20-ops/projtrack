import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_service.dart';
import 'info_card.dart';
import 'calender.dart';
import 'settings_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  String? selectedArea;        
  String? selectedProject;
  String? selectedContractor;
  DateTime? selectedDate;
  final TextEditingController dailyActualController = TextEditingController();

  List<String> areas = [];       
  List<String> projects = [];
  List<String> contractors = [];
  List<Map<String, dynamic>> rawData0001 = []; 
  
  String currentProjectCollection = '';

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    await fetchRawData0001(); 
    await extractAreasAndLoadPreferences(); 
  }

  Future<void> fetchRawData0001() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc('0001')
          .collection('progress')
          .get();
      
      setState(() {
        rawData0001 = snapshot.docs.map((doc) => doc.data()).toList();
      });
      print("🎯 Loaded 0001 Data: ${rawData0001.length} items.");
    } catch (e) {
      debugPrint("Error fetching raw data from 0001: $e");
    }
  }

  Future<void> savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedArea != null) await prefs.setString('last_area', selectedArea!);
    if (selectedProject != null) await prefs.setString('last_project', selectedProject!);
    if (selectedContractor != null) await prefs.setString('last_contractor', selectedContractor!);
    if (selectedDate != null) await prefs.setString('last_date', selectedDate!.toIso8601String());
  }

  Future<void> extractAreasAndLoadPreferences() async {
    if (rawData0001.isEmpty) return;

    Set<String> areaSet = {};
    for (var data in rawData0001) {
      if (data['The area'] != null && data['The area'].toString().trim().isNotEmpty) {
        areaSet.add(data['The area'].toString().trim());
      }
    }

    areas = areaSet.toList();
    if (areas.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    String? savedArea = prefs.getString('last_area');
    String? savedProject = prefs.getString('last_project');
    String? savedContractor = prefs.getString('last_contractor');
    String? savedDateStr = prefs.getString('last_date');

    if (savedArea != null && areas.contains(savedArea)) {
      selectedArea = savedArea;
    } else {
      selectedArea = areas.first;
    }

    filterDataByArea(selectedArea!, initialLoad: true, savedProj: savedProject, savedCont: savedContractor);

    if (savedDateStr != null) {
      selectedDate = DateTime.tryParse(savedDateStr);
    } else {
      selectedDate = DateTime.now();
    }

    setState(() {});

    if (selectedProject != null) {
      loadProjectData();
    }
  }

  void filterDataByArea(String areaName, {bool initialLoad = false, String? savedProj, String? savedCont}) {
    Set<String> projectSet = {};
    Set<String> contractorSet = {};

    for (var data in rawData0001) {
      String currentArea = data['The area']?.toString().trim() ?? "";
      if (currentArea.toLowerCase() == areaName.trim().toLowerCase()) {
        if (data['project_name'] != null && data['project_name'].toString().trim().isNotEmpty) {
          projectSet.add(data['project_name'].toString().trim());
        }
        if (data['contractor_name'] != null && data['contractor_name'].toString().trim().isNotEmpty) {
          contractorSet.add(data['contractor_name'].toString().trim());
        }
      }
    }

    setState(() {
      projects = projectSet.toList();
      contractors = contractorSet.toList();
      
      if (initialLoad) {
        selectedProject = (savedProj != null && projects.contains(savedProj)) ? savedProj : (projects.isNotEmpty ? projects.first : null);
        selectedContractor = (savedCont != null && contractors.contains(savedCont)) ? savedCont : (contractors.isNotEmpty ? contractors.first : null);
      } else {
        selectedProject = projects.isNotEmpty ? projects.first : null;
        selectedContractor = contractors.isNotEmpty ? contractors.first : null;
      }
    });

    if (selectedProject != null) {
      if (!initialLoad) updateContractorFromProject(selectedProject!);
      loadProjectData();
    }
    savePreferences(); 
  }

  void updateContractorFromProject(String projectName) {
    final matchingDoc = rawData0001.firstWhere(
      (element) => element['project_name'].toString().trim() == projectName.trim() &&
                   element['The area'].toString().trim() == selectedArea?.trim(),
      orElse: () => {},
    );
    
    if (matchingDoc.isNotEmpty && matchingDoc['contractor_name'] != null) {
      String targetContractor = matchingDoc['contractor_name'].toString().trim();
      setState(() {
        if (contractors.contains(targetContractor)) {
          selectedContractor = targetContractor;
        }
      });
      savePreferences();
    }
  }

  void updateProjectFromContractor(String contractorName) {
    final matchingDoc = rawData0001.firstWhere(
      (element) => element['contractor_name'].toString().trim() == contractorName.trim() &&
                   element['The area'].toString().trim() == selectedArea?.trim(),
      orElse: () => {},
    );
    
    if (matchingDoc.isNotEmpty && matchingDoc['project_name'] != null) {
      String targetProject = matchingDoc['project_name'].toString().trim();
      setState(() {
        if (projects.contains(targetProject)) {
          selectedProject = targetProject;
        }
      });
      loadProjectData(); 
      savePreferences();
    }
  }

  Map<String, String> projectData = {
    "plannedPercent": "0",
    "actualPercent": "0",
    "elapsedPercent": "0",
    "startDate": "🚨",
    "endDate": "🚨",
  };

  Future<void> loadProjectData() async {
    if (selectedProject != null && selectedDate != null) {
      final matchingDoc = rawData0001.firstWhere(
        (element) => element['project_name'].toString().trim() == selectedProject!.trim() &&
                     element['The area'].toString().trim() == selectedArea?.trim(),
        orElse: () => {},
      );

      String? projectPO = matchingDoc['po']?.toString().trim();

      if (projectPO != null && projectPO != '0001') {
        final data = await ProgressService.fetchProjectDataByPO(projectPO, selectedDate!);
        setState(() {
          if (data.isNotEmpty) {
            projectData = data;
            currentProjectCollection = data["activeCollection"] ?? "";
          } else {
            projectData = {
              "plannedPercent": "0",
              "actualPercent": "0",
              "elapsedPercent": "0",
              "startDate": "N/A",
              "endDate": "N/A",
            };
            currentProjectCollection = "";
          }
        });
      }
    }
  }

  Future<void> addDailyActualToFirestore() async {
    String inputText = dailyActualController.text.trim();
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (selectedProject == null || selectedDate == null || inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? "⚠️ يرجى اختيار المشروع والتاريخ وإدخال النسبة" : "⚠️ Please select project, date and enter the percentage")),
      );
      return;
    }

    String cleanedText = inputText.replaceAll(RegExp(r'[^0-9.]'), '');

    try {
      String dayOnly = DateFormat('dd').format(selectedDate!);
      String monthNum = DateFormat('MM').format(selectedDate!);
      String monthNameEn = DateFormat('MMM', 'en_US').format(selectedDate!);
      String yearFull = DateFormat('yyyy').format(selectedDate!);
      String standardId = "$yearFull-$monthNum-$dayOnly";

      final matchingDoc = rawData0001.firstWhere(
        (element) => element['project_name'].toString().trim() == selectedProject!.trim() &&
                     element['The area'].toString().trim() == selectedArea?.trim(),
        orElse: () => {},
      );
      
      String? projectPO = matchingDoc['po']?.toString().trim();

      if (projectPO == null || projectPO == '0001') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? "❌ خطأ: الـ PO غير صحيح أو مفقود" : "❌ Error: Invalid or missing PO")));
        return;
      }

      String targetCollection = currentProjectCollection;
      if (targetCollection.isEmpty) {
        for (String col in ProgressService.dataCollections) {
          final docCheck = await FirebaseFirestore.instance.collection(col).doc(projectPO).get();
          if (docCheck.exists) {
            targetCollection = col;
            break;
          }
        }
      }

      if (targetCollection.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? "❌ لم يتم العثور على مستند الـ PO ($projectPO)" : "❌ PO document not found ($projectPO)")),
        );
        return;
      }

      final collectionRef = FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(projectPO)
          .collection('progress');

      final directDoc = await collectionRef.doc(standardId).get();
      String? actualDocId;

      if (directDoc.exists) {
        actualDocId = standardId;
      } else {
        final querySnapshot = await collectionRef.get();
        for (var doc in querySnapshot.docs) {
          String id = doc.id.toLowerCase();
          if (id.contains(dayOnly) && id.contains(yearFull) && 
              (id.contains(monthNum) || id.contains(monthNameEn.toLowerCase()))) {
            actualDocId = doc.id;
            break;
          }
        }
      }

      if (actualDocId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? "❌ لم يتم العثور على سجل لهذا التاريخ" : "❌ No record found for this date")),
        );
        return;
      }

      await collectionRef.doc(actualDocId).update({
        'monthly_actual': cleanedText, 
        'contractor_name': selectedContractor,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? "✅ تم تحديث النسبة بنجاح" : "✅ Percentage updated successfully")));
      dailyActualController.clear();
      await loadProjectData(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? "❌ خطأ: $e" : "❌ Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 فحص لغة التطبيق الحالية (عربي أم إنجليزي) لتغيير النصوص ديناميكياً
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String planned = projectData["plannedPercent"] ?? "0";
    String actual = projectData["actualPercent"] ?? "0";
    String elapsed = projectData["elapsedPercent"] ?? "0";

    String plannedValue = planned.contains('%') ? planned : "$planned%";
    String actualValue = actual.contains('%') ? actual : "$actual%";
    String elapsedValue = elapsed.contains('%') ? elapsed : "$elapsed%";

    // التعامل الآمن مع نصوص التواريخ عند عدم التحديد أو فقدان البيانات
    String startVal = projectData["startDate"] == "غير محدد" || projectData["startDate"] == "لا توجد بيانات"
        ? (isArabic ? projectData["startDate"]! : "No Data")
        : projectData["startDate"]!;
        
    String endVal = projectData["endDate"] == "غير محدد" || projectData["endDate"] == "لا توجد بيانات"
        ? (isArabic ? projectData["endDate"]! : "No Data")
        : projectData["endDate"]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? "نسب الإنجاز اليومية" : "Daily Progress Percentages"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: isArabic ? 'إعدادات التطبيق' : 'App Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (areas.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Text(isArabic ? "اختر المنطقة:" : "Select Area:", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedArea,
                  items: areas.map((area) => DropdownMenuItem(value: area, child: Text(area, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedArea = value);
                      filterDataByArea(value); 
                    }
                  },
                ),
                const SizedBox(height: 15),

                Text(isArabic ? "اختر المشروع:" : "Select Project:", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedProject,
                  items: projects.map((proj) => DropdownMenuItem(value: proj, child: Text(proj, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedProject = value);
                      updateContractorFromProject(value); 
                      loadProjectData();
                    }
                  },
                ),
                const SizedBox(height: 15),

                Text(isArabic ? "اختر المقاول:" : "Select Contractor:", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedContractor,
                  items: contractors.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedContractor = value);
                      updateProjectFromContractor(value); 
                    }
                  },
                ),
                const SizedBox(height: 15),

                Text(isArabic ? "تاريخ البيانات:" : "Data Date:", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                InkWell(
                  onTap: () async {
                    final pickedDate = await Navigator.push<DateTime?>(
                      context, MaterialPageRoute(builder: (_) => const CustomCalendar()),
                    );
                    if (pickedDate != null) {
                      setState(() => selectedDate = pickedDate);
                      await loadProjectData();
                      savePreferences(); 
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedDate == null 
                            ? (isArabic ? "اضغط لاختيار التاريخ" : "Tap to select date") 
                            : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                        const Icon(Icons.calendar_month),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // تغيير عناوين بطاقات المعلومات ديناميكياً
                InfoCard(title: isArabic ? "النسبة المخططة" : "Planned Percentage", value: plannedValue),
                InfoCard(title: isArabic ? "النسبة الفعلية" : "Actual Percentage", value: actualValue),
                InfoCard(title: isArabic ? "المدة المنقضية" : "Elapsed Duration", value: elapsedValue),
                InfoCard(title: isArabic ? "تاريخ البداية" : "Start Date", value: startVal),
                InfoCard(title: isArabic ? "تاريخ النهاية" : "End Date", value: endVal),
                const SizedBox(height: 30),
                
                // تعديل ألوان الحاوية لتتناسب تلقائياً مع الثيم الفاتح والداكن (Dark Mode)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade900 : Colors.blue.shade50, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: isDarkMode ? Colors.grey.shade800 : Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isArabic ? "إضافة النسبة الفعلية اليومية:" : "Add Daily Actual Percentage:", 
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dailyActualController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: isArabic ? "مثال: 40%" : "e.g., 40%", 
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: addDailyActualToFirestore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue, 
                              shape: const CircleBorder(), 
                              padding: const EdgeInsets.all(15),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}