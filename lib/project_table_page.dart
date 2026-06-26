import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'progress_service.dart';

class ProjectTablePage extends StatefulWidget {
  const ProjectTablePage({super.key});

  @override
  State<ProjectTablePage> createState() => _ProjectTablePageState();
}

class _ProjectTablePageState extends State<ProjectTablePage> {
  DateTime? _selectedDate;
  bool _isLoading = true;
  String? _errorMsg;

  List<Map<String, dynamic>> _allRawData = [];
  List<Map<String, dynamic>> _filteredTableRows = [];
  List<String> _areasList = [];

  String? _selectedArea;
  String? _selectedStatus;
  String? _selectedAction;

  final Map<String, Map<String, dynamic>> _projectsCalculatedData = {};
  final Set<String> _fetchingPOs = {};

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  pw.Font? _arabicFont;
  bool _fontLoaded = false;

  final GlobalKey _shareButtonKey = GlobalKey();
  Rect? _sharePositionOrigin;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadArabicFont();
    _fetchAndProcessData();
  }

  Future<void> _loadArabicFont() async {
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
      _fontLoaded = true;
    } catch (_) {
      _fontLoaded = false;
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndProcessData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc('0001')
          .collection('progress')
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = "No data found inside 0001 progress collection.";
        });
        return;
      }

      List<Map<String, dynamic>> rawData =
          snapshot.docs.map((doc) => doc.data()).toList();

      Set<String> areaSet = {};
      for (var item in rawData) {
        if (item['The area'] != null &&
            item['The area'].toString().trim().isNotEmpty) {
          areaSet.add(item['The area'].toString().trim());
        }
      }

      _allRawData = rawData;
      _areasList = areaSet.toList();

      _applyFiltering();

      setState(() {
        _isLoading = false;
      });

      _loadAllProjectsCalculatedData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = e.toString();
      });
    }
  }

  void _applyFiltering() {
    List<Map<String, dynamic>> results = _allRawData;

    if (_selectedArea != null) {
      results = results.where((item) {
        String currentArea = item['The area']?.toString().trim() ?? "";
        return currentArea.toLowerCase() == _selectedArea!.trim().toLowerCase();
      }).toList();
    }

    if (_selectedStatus != null) {
      results = results.where((item) {
        String currentPO = item['po']?.toString().trim() ?? "";
        String? cachedStatus =
            _projectsCalculatedData[currentPO]?["statusText"];
        if (cachedStatus == null) return true;
        return cachedStatus.trim().toLowerCase() ==
            _selectedStatus!.trim().toLowerCase();
      }).toList();
    }

    if (_selectedAction != null) {
      results = results.where((item) {
        String currentPO = item['po']?.toString().trim() ?? "";
        String? cachedAction =
            _projectsCalculatedData[currentPO]?["requiredAction"];
        if (cachedAction == null) return true;
        return cachedAction.trim().toLowerCase() ==
            _selectedAction!.trim().toLowerCase();
      }).toList();
    }

    _filteredTableRows = results;
  }

  Future<void> _loadAllProjectsCalculatedData() async {
    if (!mounted || _selectedDate == null || _allRawData.isEmpty) return;

    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    List<Future<void>> tasks = [];

    for (var item in _allRawData) {
      final String? projectPO = item['po']?.toString().trim();

      if (projectPO != null && projectPO != '0001') {
        if (!_projectsCalculatedData.containsKey(projectPO) &&
            !_fetchingPOs.contains(projectPO)) {
          _fetchingPOs.add(projectPO);

          tasks.add(
            ProgressService.fetchProjectDataByPO(projectPO, _selectedDate!)
                .then((data) {
              if (data.isNotEmpty) {
                String planned = data["plannedPercent"] ?? "0";
                String actual = data["actualPercent"] ?? "0";
                String rawStartDate = data["startDate"] ?? "N/A";
                String rawEndDate = data["endDate"] ?? "N/A";

                String startVal =
                    rawStartDate == "Undetermined" || rawStartDate == "No Data"
                        ? (isArabic ? "لا توجد بيانات" : "No Data")
                        : rawStartDate;
                String endVal =
                    rawEndDate == "Undetermined" || rawEndDate == "No Data"
                        ? (isArabic ? "لا توجد بيانات" : "No Data")
                        : rawEndDate;

                String cleanPlanned = planned.replaceAll('%', '').trim();
                String cleanActual = actual.replaceAll('%', '').trim();
                double? plannedNum = double.tryParse(cleanPlanned);
                double? actualNum = double.tryParse(cleanActual);

                String varianceValue;
                String statusValue = isArabic ? "غير محدد" : "N/A";
                Color statusCardColor =
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
                Color textColor = isDarkMode ? Colors.white : Colors.black87;

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
                    statusCardColor = isDarkMode
                        ? Colors.green.shade900
                        : Colors.green.shade100;
                    textColor =
                        isDarkMode ? Colors.white : Colors.green.shade900;
                  } else if (variance >= 0 && variance <= 10) {
                    statusValue = isArabic ? "منتظم" : "On Track";
                    statusCardColor = isDarkMode
                        ? Colors.green.shade900
                        : Colors.green.shade100;
                    textColor =
                        isDarkMode ? Colors.white : Colors.green.shade900;
                  } else if (variance > 10 && variance <= 25) {
                    statusValue = isArabic ? "متأخر" : "Delayed";
                    statusCardColor = isDarkMode
                        ? Colors.amber.shade900
                        : Colors.amber.shade100;
                    textColor =
                        isDarkMode ? Colors.white : Colors.amber.shade900;
                  } else if (variance > 25) {
                    statusValue = isArabic ? "متعثر" : "Troubled";
                    statusCardColor =
                        isDarkMode ? Colors.red.shade900 : Colors.red.shade100;
                    textColor = isDarkMode ? Colors.white : Colors.red.shade900;
                  }
                }

                String requiredAction = _getRequiredAction(varianceValue, isArabic);
                _projectsCalculatedData[projectPO] = {
                  "planned": planned.contains('%') ? planned : "$planned%",
                  "actual": actual.contains('%') ? actual : "$actual%",
                  "variance": varianceValue,
                  "statusText": statusValue,
                  "statusColor": statusCardColor,
                  "textColor": textColor,
                  "startDate": startVal,
                  "endDate": endVal,
                  "requiredAction": requiredAction,
                };
              } else {
                _projectsCalculatedData[projectPO] = {
                  "planned": "0%",
                  "actual": "0%",
                  "variance": "0%",
                  "statusText": isArabic ? "غير محدد" : "N/A",
                  "statusColor":
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  "textColor": isDarkMode ? Colors.white : Colors.black87,
                  "startDate": isArabic ? "لا توجد بيانات" : "No Data",
                  "endDate": isArabic ? "لا توجد بيانات" : "No Data",
                  "requiredAction": isArabic ? "لا يوجد" : "None",
                };
              }
            }).catchError((_) {
              _projectsCalculatedData[projectPO] = {
                "planned": "0%",
                "actual": "0%",
                "variance": "0%",
                "statusText": isArabic ? "غير محدد" : "N/A",
                "statusColor":
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                "textColor": isDarkMode ? Colors.white : Colors.black87,
                "startDate": isArabic ? "لا توجد بيانات" : "No Data",
                "endDate": isArabic ? "لا توجد بيانات" : "No Data",
                "requiredAction": isArabic ? "لا يوجد" : "None",
              };
            }).whenComplete(() {
              _fetchingPOs.remove(projectPO);
              if (mounted) {
                setState(() {
                  _applyFiltering();
                });
              }
            }),
          );
        }
      }
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _projectsCalculatedData.clear();
        _fetchingPOs.clear();
        _applyFiltering();
      });
      _loadAllProjectsCalculatedData();
    }
  }

  String _getRequiredAction(String varianceStr, bool isArabic) {
    String clean = varianceStr.replaceAll('%', '').trim();
    double? v = double.tryParse(clean);
    if (v == null || v < 5) return isArabic ? "لا يوجد" : "None";
    if (v >= 5 && v < 15) return isArabic ? "خطاب حث أول + تقديم خطه تصحيحيه" : "1st Reminder Letter + Recovery Plan";
    if (v >= 15 && v < 20) return isArabic ? "خطاب حث ثاني + تقديم خطه تصحيحيه" : "2nd Reminder Letter + Recovery Plan";
    return isArabic ? "خطاب إنذار أول" : "1st Warning Letter";
  }

  void _shareMenu() {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(isArabic ? "تصدير كملف PDF" : "Export as PDF"),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAndSharePdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: Text(isArabic ? "تصدير كملف Excel" : "Export as Excel"),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAndShareExcel();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportAndSharePdf() async {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_filteredTableRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? "لا توجد بيانات" : "No data")),
      );
      return;
    }

    if (!_fontLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic
              ? "خطأ: تأكد من وضع ملف NotoSansArabic-Regular.ttf في assets/fonts/"
              : "Error: Put NotoSansArabic-Regular.ttf in assets/fonts/"),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      List<String> headers = isArabic
          ? [
              "المنطقة",
              "أمر الشراء",
              "المشروع",
              "المقاول",
              "تاريخ البداية",
              "تاريخ النهاية",
              "النسبة المخططة",
              "النسبة الفعلية",
              "الانحراف",
              "الحالة",
              "الإجراءات المطلوبة"
            ]
          : [
              "Area",
              "PO",
              "Project",
              "Contractor",
              "Start Date",
              "End Date",
              "Planned %",
              "Actual %",
              "Variance",
              "Status",
              "Required Action"
            ];

      List<List<String>> rows = _filteredTableRows.map<List<String>>((item) {
        String po = item['po']?.toString().trim() ?? "-";
        var d = _projectsCalculatedData[po];
        return [
          item['The area']?.toString() ?? "-",
          po,
          item['project_name']?.toString() ?? "-",
          item['contractor_name']?.toString() ?? "-",
          d?["startDate"] ?? "-",
          d?["endDate"] ?? "-",
          d?["planned"] ?? "-",
          d?["actual"] ?? "-",
          d?["variance"] ?? "-",
          d?["statusText"] ?? (isArabic ? "غير محدد" : "N/A"),
          d?["requiredAction"] ?? (isArabic ? "لا يوجد" : "None"),
        ];
      }).toList();

      pw.TextDirection textDirOf(String text) =>
          RegExp(r'[\u0600-\u06FF]').hasMatch(text)
              ? pw.TextDirection.rtl
              : pw.TextDirection.ltr;

      String dateStr = _selectedDate != null
          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : (isArabic ? "غير محدد" : "Not selected");

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => [
            pw.Center(
              child: pw.Text(
                isArabic ? "تاريخ البيانات: $dateStr" : "Data Date: $dateStr",
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                    font: _arabicFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1.0),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(1.2),
                7: const pw.FlexColumnWidth(1.2),
                8: const pw.FlexColumnWidth(1.2),
                9: const pw.FlexColumnWidth(1.2),
                10: const pw.FlexColumnWidth(2.0),
              },
              children: [
                pw.TableRow(
                  children: headers
                      .map((h) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 3, vertical: 4),
                            color: PdfColors.blue50,
                            child: pw.Text(
                              h,
                              textDirection: textDirOf(h),
                              style: pw.TextStyle(
                                  font: _arabicFont,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7),
                              textAlign: pw.TextAlign.center,
                            ),
                          ))
                      .toList(),
                ),
                ...rows.map((row) => pw.TableRow(
                      children: row
                          .map((cell) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 2),
                                child: pw.Text(
                                  cell,
                                  textDirection: textDirOf(cell),
                                  style: pw.TextStyle(
                                      font: _arabicFont, fontSize: 6),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ))
                          .toList(),
                    )),
              ],
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/project_table.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: isArabic ? "بيانات جدول المشاريع" : "Project Table Data",
        sharePositionOrigin: _sharePositionOrigin,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${isArabic ? "خطأ في PDF" : "PDF Error"}: $e")),
      );
    }
  }

  Future<void> _exportAndShareExcel() async {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_filteredTableRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? "لا توجد بيانات" : "No data")),
      );
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      String dateStr = _selectedDate != null
          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : (isArabic ? "غير محدد" : "Not selected");

      sheet.appendRow([
        TextCellValue(
            isArabic ? "تاريخ البيانات: $dateStr" : "Data Date: $dateStr"),
      ]);
      sheet.appendRow([]);

      sheet.appendRow(isArabic
          ? [
              TextCellValue("المنطقة"),
              TextCellValue("أمر الشراء"),
              TextCellValue("المشروع"),
              TextCellValue("المقاول"),
              TextCellValue("تاريخ البداية"),
              TextCellValue("تاريخ النهاية"),
              TextCellValue("النسبة المخططة"),
              TextCellValue("النسبة الفعلية"),
              TextCellValue("الانحراف"),
              TextCellValue("الحالة"),
              TextCellValue("الإجراءات المطلوبة")
            ]
          : [
              TextCellValue("Area"),
              TextCellValue("PO"),
              TextCellValue("Project"),
              TextCellValue("Contractor"),
              TextCellValue("Start Date"),
              TextCellValue("End Date"),
              TextCellValue("Planned %"),
              TextCellValue("Actual %"),
              TextCellValue("Variance"),
              TextCellValue("Status"),
              TextCellValue("Required Action")
            ]);

      for (var item in _filteredTableRows) {
        String po = item['po']?.toString().trim() ?? "-";
        var d = _projectsCalculatedData[po];
        sheet.appendRow([
          TextCellValue(item['The area']?.toString() ?? "-"),
          TextCellValue(po),
          TextCellValue(item['project_name']?.toString() ?? "-"),
          TextCellValue(item['contractor_name']?.toString() ?? "-"),
          TextCellValue(d?["startDate"] ?? "-"),
          TextCellValue(d?["endDate"] ?? "-"),
          TextCellValue(d?["planned"] ?? "-"),
          TextCellValue(d?["actual"] ?? "-"),
          TextCellValue(d?["variance"] ?? "-"),
          TextCellValue(d?["statusText"] ?? (isArabic ? "غير محدد" : "N/A")),
          TextCellValue(d?["requiredAction"] ?? (isArabic ? "لا يوجد" : "None")),
        ]);
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/project_table.xlsx');
      final encodedBytes = excel.encode();
      if (encodedBytes != null) {
        await file.writeAsBytes(encodedBytes);
      }

      await Share.shareXFiles(
        [
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: isArabic ? "بيانات جدول المشاريع" : "Project Table Data",
        sharePositionOrigin: _sharePositionOrigin,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("${isArabic ? "خطأ في Excel" : "Excel Error"}: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    List<String> statusDropdownItems = isArabic
        ? ["منتظم", "متأخر", "متعثر", "متقدم", "غير محدد"]
        : ["On Track", "Delayed", "Troubled", "Ahead", "N/A"];

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isArabic ? "جدول المشاريع المطور" : "Advanced Project Table"),
        centerTitle: true,
        actions: [
          IconButton(
            key: _shareButtonKey,
            icon: const Icon(Icons.share),
            tooltip: isArabic ? "مشاركة البيانات" : "Share data",
            onPressed: () {
              final RenderBox? box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                _sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
              }
              _shareMenu();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg != null
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                        isArabic ? "حدث خطأ: $_errorMsg" : "Error: $_errorMsg"),
                  ))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(isArabic ? "اختر المنطقة:" : "Select Area:",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          value: _selectedArea,
                          items: [
                            DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                    isArabic ? "كل المناطق" : "All Areas",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue))),
                            ..._areasList.map((area) =>
                                DropdownMenuItem<String?>(
                                    value: area,
                                    child: Text(area,
                                        style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedArea = value;
                              _applyFiltering();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(isArabic ? "تاريخ البيانات:" : "Data Date:",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Card(
                          margin: EdgeInsets.zero,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  color: Colors.grey.shade400, width: 1),
                              borderRadius: BorderRadius.circular(8)),
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month,
                                      color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(
                                          _selectedDate == null
                                              ? (isArabic
                                                  ? "اضغط لاختيار التاريخ"
                                                  : "Tap to select date")
                                              : "${_selectedDate!.toLocal()}"
                                                  .split(' ')[0],
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87))),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(isArabic ? "حالة المشروع:" : "Project Status:",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          value: _selectedStatus,
                          items: [
                            DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                    isArabic ? "كل الحالات" : "All Statuses",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue))),
                            ...statusDropdownItems.map((status) =>
                                DropdownMenuItem<String?>(
                                    value: status,
                                    child: Text(status,
                                        style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                              _applyFiltering();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(isArabic ? "الإجراءات المطلوبة:" : "Required Action:",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          value: _selectedAction,
                          items: [
                            DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                    isArabic ? "كل الإجراءات" : "All Actions",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue))),
                            ...[
                              isArabic
                                  ? "لا يوجد"
                                  : "None",
                              isArabic
                                  ? "خطاب حث أول + تقديم خطه تصحيحيه"
                                  : "1st Reminder Letter + Recovery Plan",
                              isArabic ? "خطاب حث ثاني + تقديم خطه تصحيحيه" : "2nd Reminder Letter + Recovery Plan",
                              isArabic ? "خطاب إنذار أول" : "1st Warning Letter",
                            ].map((action) => DropdownMenuItem<String?>(
                                    value: action,
                                    child: Text(action,
                                        style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedAction = value;
                              _applyFiltering();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Scrollbar(
                                controller: _verticalScrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _verticalScrollController,
                                  scrollDirection: Axis.vertical,
                                  child: Scrollbar(
                                    controller: _horizontalScrollController,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    notificationPredicate: (notif) =>
                                        notif.depth == 1,
                                    child: SingleChildScrollView(
                                      controller: _horizontalScrollController,
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        border: TableBorder.all(
                                            color: Colors.grey.shade300,
                                            width: 0.5),
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                                Colors.blue.shade50),
                                        columnSpacing: 8,
                                        dataRowMinHeight: 28,
                                        dataRowMaxHeight: 36,
                                        headingRowHeight: 36,
                                        columns: [
                                          DataColumn(
                                              label: Text(
                                                  isArabic ? 'المنطقة' : 'Area',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'أمر الشراء'
                                                      : 'PO',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'المشروع'
                                                      : 'Project',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'المقاول'
                                                      : 'Contractor',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'تاريخ البداية'
                                                      : 'Start Date',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'تاريخ النهاية'
                                                      : 'End Date',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'النسبة المخططة'
                                                      : 'Planned %',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.indigo))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'النسبة الفعلية'
                                                      : 'Actual %',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors
                                                          .green.shade700))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'الانحراف'
                                                      : 'Variance',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color:
                                                          Colors.deepOrange))),
                                          DataColumn(
                                              label: Text(
                                                  '${isArabic ? 'حالة المشروع' : 'Status'} (${_filteredTableRows.length})',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.black87))),
                                          DataColumn(
                                              label: Text(
                                                  isArabic
                                                      ? 'الإجراءات المطلوبة'
                                                      : 'Required Action',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Colors.red))),
                                        ],
                                        rows: _filteredTableRows.map((item) {
                                          String currentPO =
                                              item['po']?.toString().trim() ??
                                                  "";
                                          bool isRowLoading = _fetchingPOs
                                                  .contains(currentPO) &&
                                              !_projectsCalculatedData
                                                  .containsKey(currentPO);
                                          String plannedPercent =
                                              _projectsCalculatedData[currentPO]
                                                      ?["planned"] ??
                                                  (isRowLoading ? "..." : "-");
                                          String actualPercent =
                                              _projectsCalculatedData[currentPO]
                                                      ?["actual"] ??
                                                  (isRowLoading ? "..." : "-");
                                          String variance =
                                              _projectsCalculatedData[currentPO]
                                                      ?["variance"] ??
                                                  (isRowLoading ? "..." : "-");
                                          String statusText =
                                              _projectsCalculatedData[currentPO]
                                                      ?["statusText"] ??
                                                  (isRowLoading
                                                      ? "..."
                                                      : (isArabic
                                                          ? "غير محدد"
                                                          : "N/A"));
                                          Color statusColor =
                                              _projectsCalculatedData[currentPO]
                                                      ?["statusColor"] ??
                                                  (isDarkMode
                                                      ? Colors.grey.shade800
                                                      : Colors.grey.shade200);
                                          Color textColor =
                                              _projectsCalculatedData[currentPO]
                                                      ?["textColor"] ??
                                                  (isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87);
                                          String startDate =
                                              _projectsCalculatedData[currentPO]
                                                      ?["startDate"] ??
                                                  (isRowLoading ? "..." : "-");
                                          String endDate =
                                              _projectsCalculatedData[currentPO]
                                                      ?["endDate"] ??
                                                  (isRowLoading ? "..." : "-");
                                          String requiredAction =
                                              _projectsCalculatedData[currentPO]
                                                      ?["requiredAction"] ??
                                                  (isArabic ? "لا يوجد" : "None");

                                          return DataRow(cells: [
                                            DataCell(Text(
                                                item['The area']?.toString() ??
                                                    "-",
                                                style: const TextStyle(
                                                    fontSize: 11))),
                                            DataCell(Text(
                                                currentPO.isEmpty
                                                    ? "-"
                                                    : currentPO,
                                                style: const TextStyle(
                                                    fontSize: 11))),
                                            DataCell(Text(
                                                item['project_name']
                                                        ?.toString() ??
                                                    "-",
                                                style: const TextStyle(
                                                    fontSize: 11))),
                                            DataCell(Text(
                                                item['contractor_name']
                                                        ?.toString() ??
                                                    "-",
                                                style: const TextStyle(
                                                    fontSize: 11))),
                                            DataCell(Text(startDate,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        startDate.contains('🚨')
                                                            ? Colors.red
                                                            : null))),
                                            DataCell(Text(endDate,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        endDate.contains('🚨')
                                                            ? Colors.red
                                                            : null))),
                                            DataCell(Text(plannedPercent,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors.indigo))),
                                            DataCell(Text(actualPercent,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors
                                                        .green.shade700))),
                                            DataCell(Text(variance,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors.deepOrange))),
                                            DataCell(Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: statusColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                                child: Text(statusText,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                        color: textColor)))),
                                            DataCell(Text(requiredAction,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors.red))),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
