import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_service.dart';
import 'info_card.dart';
import 'calender.dart';
import 'settings_page.dart';
import 'project_table_page.dart';

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
  String budgetCostValue = '';
  String projectSummaryValue = '';

  Map<String, String> projectData = {
    "plannedPercent": "0",
    "actualPercent": "0",
    "elapsedPercent": "0",
    "startDate": "🚨",
    "endDate": "🚨",
  };

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    dailyActualController.dispose();
    super.dispose();
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
    if (selectedProject != null) {
      await prefs.setString('last_project', selectedProject!);
    }
    if (selectedContractor != null) {
      await prefs.setString('last_contractor', selectedContractor!);
    }
    if (selectedDate != null) {
      await prefs.setString('last_date', selectedDate!.toIso8601String());
    }
  }

  Future<void> extractAreasAndLoadPreferences() async {
    if (rawData0001.isEmpty) return;

    Set<String> areaSet = {};
    for (var data in rawData0001) {
      if (data['The area'] != null &&
          data['The area'].toString().trim().isNotEmpty) {
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

    filterDataByArea(selectedArea!,
        initialLoad: true, savedProj: savedProject, savedCont: savedContractor);

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

  void filterDataByArea(String areaName,
      {bool initialLoad = false, String? savedProj, String? savedCont}) {
    Set<String> projectSet = {};
    Set<String> contractorSet = {};

    for (var data in rawData0001) {
      String currentArea = data['The area']?.toString().trim() ?? "";
      if (currentArea.toLowerCase() == areaName.trim().toLowerCase()) {
        if (data['project_name'] != null &&
            data['project_name'].toString().trim().isNotEmpty) {
          projectSet.add(data['project_name'].toString().trim());
        }
        if (data['contractor_name'] != null &&
            data['contractor_name'].toString().trim().isNotEmpty) {
          contractorSet.add(data['contractor_name'].toString().trim());
        }
      }
    }

    setState(() {
      projects = projectSet.toList();
      contractors = contractorSet.toList();

      if (initialLoad) {
        selectedProject = (savedProj != null && projects.contains(savedProj))
            ? savedProj
            : (projects.isNotEmpty ? projects.first : null);
        selectedContractor =
            (savedCont != null && contractors.contains(savedCont))
                ? savedCont
                : (contractors.isNotEmpty ? contractors.first : null);
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
      (element) =>
          element['project_name'].toString().trim().toLowerCase() ==
              projectName.trim().toLowerCase() &&
          element['The area'].toString().trim().toLowerCase() ==
              selectedArea?.trim().toLowerCase(),
      orElse: () => {},
    );

    if (matchingDoc.isNotEmpty && matchingDoc['contractor_name'] != null) {
      String targetContractor =
          matchingDoc['contractor_name'].toString().trim();
      setState(() {
        if (contractors.contains(targetContractor)) {
          selectedContractor = targetContractor;
        } else {
          selectedContractor =
              contractors.isNotEmpty ? contractors.first : null;
        }
      });
      savePreferences();
    }
  }

  void updateProjectFromContractor(String contractorName) {
    final matchingDoc = rawData0001.firstWhere(
      (element) =>
          element['contractor_name'].toString().trim().toLowerCase() ==
              contractorName.trim().toLowerCase() &&
          element['The area'].toString().trim().toLowerCase() ==
              selectedArea?.trim().toLowerCase(),
      orElse: () => {},
    );

    if (matchingDoc.isNotEmpty && matchingDoc['project_name'] != null) {
      String targetProject = matchingDoc['project_name'].toString().trim();
      setState(() {
        if (projects.contains(targetProject)) {
          selectedProject = targetProject;
        } else {
          selectedProject = projects.isNotEmpty ? projects.first : null;
        }
      });
      loadProjectData();
      savePreferences();
    }
  }

  Future<void> loadProjectData() async {
    if (selectedProject != null && selectedArea != null) {
      final matchingDoc = rawData0001.firstWhere(
        (element) =>
            element['project_name'].toString().trim().toLowerCase() ==
                selectedProject!.trim().toLowerCase() &&
            element['The area'].toString().trim().toLowerCase() ==
                selectedArea!.trim().toLowerCase(),
        orElse: () => {},
      );

      setState(() {
        if (matchingDoc.isNotEmpty && matchingDoc['Budget cost'] != null) {
          String rawCost = matchingDoc['Budget cost'].toString().trim();
          String cleanCost = rawCost.replaceAll(',', '');
          double? costNum = double.tryParse(cleanCost);

          if (costNum != null) {
            var formatter = NumberFormat('#,###.##');
            budgetCostValue = formatter.format(costNum);
          } else {
            budgetCostValue = rawCost;
          }
        } else {
          budgetCostValue = '';
        }

        if (matchingDoc.isNotEmpty && matchingDoc['Project Summary'] != null) {
          projectSummaryValue =
              matchingDoc['Project Summary'].toString().trim();
        } else {
          projectSummaryValue = '';
        }
      });

      if (selectedDate != null) {
        String? projectPO = matchingDoc['po']?.toString().trim();

        if (projectPO != null && projectPO != '0001') {
          final data = await ProgressService.fetchProjectDataByPO(
              projectPO, selectedDate!);
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
  }

  Future<void> addDailyActualToFirestore() async {
    String inputText = dailyActualController.text.trim();
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (selectedProject == null || selectedDate == null || inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic
              ? "⚠️ يرجى اختيار المشروع والتاريخ، وإدخال النسبة المئوية"
              : "⚠️ Please select a project and date, and enter the percentage"),
        ),
      );
      return;
    }

    final matchingDoc = rawData0001.firstWhere(
      (element) =>
          element['project_name'].toString().trim().toLowerCase() ==
              selectedProject!.trim().toLowerCase() &&
          element['The area'].toString().trim().toLowerCase() ==
              selectedArea?.trim().toLowerCase(),
      orElse: () => {},
    );

    String? projectAdmin = matchingDoc['admin']?.toString().trim();
    final currentUser = FirebaseAuth.instance.currentUser;
    String? currentUserEmail = currentUser?.email?.trim();

    if (projectAdmin == null ||
        currentUserEmail == null ||
        currentUserEmail.toLowerCase() != projectAdmin.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic
              ? "المهندس الاستشاري المعتمد للمشروع فقط هو من يمكنه تسجيل النسبة الفعلية"
              : "Only the Authorized Project Consultant Engineer can enter the actual progress percentage"),
          backgroundColor: Colors.red,
        ),
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

      String? projectPO = matchingDoc['po']?.toString().trim();

      if (projectPO == null || projectPO == '0001') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? "❌ خطأ: رقم أمر الشراء غير صحيح أو مفقود"
                : "❌ Error: The PO is invalid or missing"),
          ),
        );
        return;
      }

      String targetCollection = currentProjectCollection;
      if (targetCollection.isEmpty) {
        for (String col in ProgressService.dataCollections) {
          final docCheck = await FirebaseFirestore.instance
              .collection(col)
              .doc(projectPO)
              .get();
          if (docCheck.exists) {
            targetCollection = col;
            break;
          }
        }
      }

      if (targetCollection.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? "❌ لم يتم العثور على مستند أمر الشراء ($projectPO)"
                : "❌ The PO ($projectPO) document was not found"),
          ),
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
          if (id.contains(dayOnly) &&
              id.contains(yearFull) &&
              (id.contains(monthNum) ||
                  id.contains(monthNameEn.toLowerCase()))) {
            actualDocId = doc.id;
            break;
          }
        }
      }

      if (actualDocId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? "❌ لم يتم العثور على سجل لهذا التاريخ"
                : "❌ No record found for this date"),
          ),
        );
        return;
      }

      await collectionRef.doc(actualDocId).update({
        'monthly_actual': cleanedText,
        'contractor_name': selectedContractor,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic
              ? "✅ تم تحديث النسبة المئوية بنجاح"
              : "✅ Percentage successfully updated"),
        ),
      );
      dailyActualController.clear();
      await loadProjectData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? "❌ خطأ: $e" : "❌ Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    String planned = projectData["plannedPercent"] ?? "0";
    String actual = projectData["actualPercent"] ?? "0";
    String elapsed = projectData["elapsedPercent"] ?? "0";

    String plannedValue = planned.contains('%') ? planned : "$planned%";
    String actualValue = actual.contains('%') ? actual : "$actual%";
    String elapsedValue = elapsed.contains('%') ? elapsed : "$elapsed%";

    String varianceValue;
    String statusValue = isArabic ? "غير محدد" : "N/A";

    Color statusCardColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;

    String cleanPlanned = planned.replaceAll('%', '').trim();
    String cleanActual = actual.replaceAll('%', '').trim();

    double? plannedNum = double.tryParse(cleanPlanned);
    double? actualNum = double.tryParse(cleanActual);

    if (actualNum == null ||
        actualNum == 0 ||
        cleanActual.isEmpty ||
        cleanActual == "0") {
      varianceValue = isArabic
          ? "يجب إضافة النسبة الفعالية"
          : "Actual percentage should be added";
    } else {
      double pNum = plannedNum ?? 0.0;
      double variance = pNum - actualNum;

      varianceValue =
          "${variance.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}%";

      if (variance < 0) {
        statusValue = isArabic ? "متقدم" : "Ahead";
        statusCardColor =
            isDarkMode ? Colors.green.shade900 : Colors.green.shade100;
      } else if (variance >= 0 && variance <= 10) {
        statusValue = isArabic ? "منتظم" : "On Track";
        statusCardColor =
            isDarkMode ? Colors.green.shade900 : Colors.green.shade100;
      } else if (variance > 10 && variance <= 25) {
        statusValue = isArabic ? "متأخر" : "Delayed";
        statusCardColor =
            isDarkMode ? Colors.amber.shade900 : Colors.amber.shade100;
      } else if (variance > 25) {
        statusValue = isArabic ? "متعثر" : "Troubled";
        statusCardColor =
            isDarkMode ? Colors.red.shade900 : Colors.red.shade100;
      }
    }

    String startVal = projectData["startDate"] == "Undetermined" ||
            projectData["startDate"] == "No Data"
        ? (isArabic ? "لا توجد بيانات" : "No Data")
        : projectData["startDate"]!;

    String endVal = projectData["endDate"] == "Undetermined" ||
            projectData["endDate"] == "No Data"
        ? (isArabic ? "لا توجد بيانات" : "No Data")
        : projectData["endDate"]!;

    String displayBudgetCost = budgetCostValue.isNotEmpty
        ? budgetCostValue
        : (isArabic ? "لا توجد بيانات" : "No Data");

    String displayProjectSummary = projectSummaryValue.isNotEmpty
        ? projectSummaryValue
        : (isArabic
            ? "لا يوجد وصف لنطاق المشروع حالياً"
            : "No project scope description currently available");

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isArabic ? "نسب الإنجاز اليومية" : "Daily Progress Percentages"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: isArabic ? 'جدول المشاريع' : 'Project Table',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProjectTablePage()),
              );
            },
          ),
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
                Text(isArabic ? "اختر المنطقه:" : "Select Area:",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: areas.contains(selectedArea) ? selectedArea : null,
                  items: areas
                      .map((area) => DropdownMenuItem<String>(
                          value: area,
                          child:
                              Text(area, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedArea = value);
                      filterDataByArea(value);
                    }
                  },
                ),
                const SizedBox(height: 15),
                Text(isArabic ? "اختر المشروع:" : "Select Project:",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: (selectedProject != null &&
                          projects.contains(selectedProject))
                      ? selectedProject
                      : null,
                  items: projects
                      .map((proj) => DropdownMenuItem<String>(
                          value: proj,
                          child:
                              Text(proj, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedProject = value);
                      updateContractorFromProject(value);
                      loadProjectData();
                    }
                  },
                ),
                const SizedBox(height: 15),
                Text(isArabic ? "اختر المقاول:" : "Select Contractor:",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: (selectedContractor != null &&
                          contractors.contains(selectedContractor))
                      ? selectedContractor
                      : null,
                  items: contractors
                      .map((c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedContractor = value);
                      updateProjectFromContractor(value);
                    }
                  },
                ),
                const SizedBox(height: 15),
                Text(isArabic ? "تاريخ البيانات:" : "Data Date:",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                InkWell(
                  onTap: () async {
                    final pickedDate = await Navigator.push<DateTime?>(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomCalendar()),
                    );
                    if (pickedDate != null) {
                      setState(() => selectedDate = pickedDate);
                      await loadProjectData();
                      savePreferences();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedDate == null
                            ? (isArabic
                                ? "اضغط لاختيار التاريخ"
                                : "Tap to select date")
                            : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                        const Icon(Icons.calendar_month),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                InfoCard(
                    title: isArabic ? "النسبة المخططة" : "Planned Percentage",
                    value: plannedValue),
                InfoCard(
                    title: isArabic ? "النسبة الفعلية" : "Actual Percentage",
                    value: actualValue),
                InfoCard(
                    title: isArabic ? "الانحراف" : "Variance",
                    value: varianceValue),
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.black12,
                      width: 1,
                    ),
                  ),
                  color: statusCardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? "حالة المشروع" : "Project Status",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          statusValue,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InfoCard(
                    title: isArabic ? "المدة المنقضية" : "Elapsed Duration",
                    value: elapsedValue),
                InfoCard(
                    title: isArabic ? "قيمة المشروع" : "Budget Cost",
                    value: displayBudgetCost),
                InfoCard(
                    title: isArabic ? "تاريخ البداية" : "Start Date",
                    value: startVal),
                InfoCard(
                    title: isArabic ? "تاريخ النهاية" : "Finish Date",
                    value: endVal),
                const SizedBox(height: 15),
                Text(
                  isArabic ? "نطاق المشروع:" : "Project Scope:",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode ? Colors.white24 : Colors.black12,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    displayProjectSummary,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.87)
                          : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode ? Colors.grey.shade900 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isArabic
                            ? "إضافة النسبة الفعلية اليومية:"
                            : "Add Daily Actual Percentage:",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dailyActualController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
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
