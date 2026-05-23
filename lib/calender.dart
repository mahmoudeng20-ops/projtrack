import 'package:flutter/material.dart';

class CustomCalendar extends StatefulWidget {
  const CustomCalendar({super.key});

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
    final firstWeekday = DateTime(selectedYear, selectedMonth, 1).weekday;

    return Scaffold(
      appBar: AppBar(title: const Text("اختيار التاريخ")),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // اختيار السنة والشهر
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: selectedYear,
                items: List.generate(30, (index) => 2000 + index)
                    .map((year) => DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedYear = value;
                  });
                },
              ),
              const SizedBox(width: 20),
              DropdownButton<int>(
                value: selectedMonth,
                items: List.generate(12, (index) => index + 1)
                    .map((month) => DropdownMenuItem(
                          value: month,
                          child: Text(_getMonthName(month)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedMonth = value;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            "${_getMonthName(selectedMonth)} - $selectedYear",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          // أسماء أيام الأسبوع
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(child: Center(child: Text("الإثنين", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("الثلاثاء", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("الأربعاء", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("الخميس", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("الجمعة", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("السبت", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("الأحد", style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // شبكة الأيام
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: daysInMonth + (firstWeekday - 1),
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox.shrink();
                }

                final day = index - (firstWeekday - 2);
                final date = DateTime(selectedYear, selectedMonth, day);

                final isSelected = selectedDate != null &&
                    selectedDate!.year == date.year &&
                    selectedDate!.month == date.month &&
                    selectedDate!.day == date.day;

                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedDate = date;
                    });
                  },
                  onDoubleTap: () {
                    // ✅ عند التأكيد، نرجع التاريخ بصيغة يوم-شهر-سنة
                    final formattedDate =
                        "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year.toString()}";
                    Navigator.pop(context, DateTime.parse("${date.year}-${date.month}-${date.day}"));
                    debugPrint("📅 التاريخ المختار: $formattedDate");
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // زر تأكيد
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: selectedDate == null
                  ? null
                  : () {
                      // ✅ نرجع التاريخ بنفس التنسيق المستخدم في Firestore
                      final formattedDate =
                          "${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year.toString()}";
                      Navigator.pop(context, selectedDate);
                      debugPrint("📅 تم تأكيد التاريخ: $formattedDate");
                    },
              child: const Text("تأكيد التاريخ"),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
      "",
      "يناير",
      "فبراير",
      "مارس",
      "أبريل",
      "مايو",
      "يونيو",
      "يوليو",
      "أغسطس",
      "سبتمبر",
      "أكتوبر",
      "نوفمبر",
      "ديسمبر",
    ];
    return names[month];
  }
}
