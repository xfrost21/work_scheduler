import 'package:flutter/material.dart';
import '../models/work_shift.dart';
import '../models/app_settings.dart';

class ShiftCalculator {
  static bool isHoliday(DateTime day, AppSettings settings) {
    bool isCompanyHoliday = settings.customHolidays.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    );
    if (isCompanyHoliday) return true;

    final fixedHolidays = [
      [1, 1],
      [6, 1],
      [1, 5],
      [3, 5],
      [15, 8],
      [1, 11],
      [11, 11],
      [25, 12],
      [26, 12],
    ];
    for (var h in fixedHolidays) {
      if (day.day == h[0] && day.month == h[1]) return true;
    }

    int y = day.year;
    int a = y % 19;
    int b = y ~/ 100;
    int c = y % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int month = (h + l - 7 * m + 114) ~/ 31;
    int dDay = ((h + l - 7 * m + 114) % 31) + 1;
    DateTime easter = DateTime(y, month, dDay);

    return (day.year == easter.year &&
            day.month == easter.month &&
            day.day == easter.day) ||
        (day.year == easter.year &&
            day.month == easter.month &&
            day.day == easter.add(const Duration(days: 1)).day) ||
        (day.year == easter.year &&
            day.month == easter.add(const Duration(days: 49)).month &&
            day.day == easter.add(const Duration(days: 49)).day) ||
        (day.year == easter.year &&
            day.month == easter.add(const Duration(days: 60)).month &&
            day.day == easter.add(const Duration(days: 60)).day);
  }

  static Map<String, dynamic> calculatePay(
    WorkShift shift,
    AppSettings settings,
  ) {
    if (shift.type == 'sick') {
      double pay = (settings.averageMonthlyNet / 30.0) * 0.8;
      return {'pay': pay, 'total': 0.0};
    }
    if (shift.type == 'off') return {'pay': 0.0, 'total': 0.0};

    DateTime startDT = DateTime(
      shift.date.year,
      shift.date.month,
      shift.date.day,
      shift.startTime.hour,
      shift.startTime.minute,
    );
    DateTime endDT = DateTime(
      shift.date.year,
      shift.date.month,
      shift.date.day,
      shift.endTime.hour,
      shift.endTime.minute,
    );
    if (endDT.isBefore(startDT) || endDT.isAtSameMomentAs(startDT))
      endDT = endDT.add(const Duration(days: 1));

    int totalMinutes = endDT.difference(startDT).inMinutes;
    int mReg = 0;
    int mNight = 0;
    int mHReg = 0;
    int mHNight = 0;

    for (int i = 0; i < totalMinutes; i++) {
      DateTime cur = startDT.add(Duration(minutes: i));
      bool isH = isHoliday(cur, settings);
      bool isN = (cur.hour >= 22 || cur.hour < 6);
      if (isH && isN)
        mHNight++;
      else if (isH && !isN)
        mHReg++;
      else if (!isH && isN)
        mNight++;
      else
        mReg++;
    }

    int bLeft = 15;
    if (totalMinutes > bLeft) {
      int s = (mReg >= bLeft) ? bLeft : mReg;
      mReg -= s;
      bLeft -= s;
      if (bLeft > 0) {
        s = (mHReg >= bLeft) ? bLeft : mHReg;
        mHReg -= s;
        bLeft -= s;
      }
      if (bLeft > 0) {
        s = (mNight >= bLeft) ? bLeft : mNight;
        mNight -= s;
        bLeft -= s;
      }
      if (bLeft > 0) {
        s = (mHNight >= bLeft) ? bLeft : mHNight;
        mHNight -= s;
        bLeft -= s;
      }
    }

    double r = settings.hourlyRateNet;
    double b = settings.holidayBonus;
    return {
      'total': (totalMinutes > 15 ? totalMinutes - 15 : totalMinutes) / 60.0,
      'pay':
          (mReg / 60 * r) +
          (mHReg / 60 * (r + b)) +
          (mNight / 60 * r * 1.2) +
          (mHNight / 60 * (r + b) * 1.2),
    };
  }
}
