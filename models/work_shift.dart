import 'package:flutter/material.dart';

class WorkShift {
  final String id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double totalHours;
  final double estimatedPay;
  final bool isCompleted;
  final String type; // 'work', 'off', 'sick'
  final double overtimeRate;
  final double sickPayRate; // NOWE: 0.8 lub 1.0
  final String notes;

  WorkShift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalHours,
    required this.estimatedPay,
    required this.isCompleted,
    required this.type,
    this.overtimeRate = 1.0,
    this.sickPayRate = 0.8,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'totalHours': totalHours,
      'estimatedPay': estimatedPay,
      'isCompleted': isCompleted,
      'type': type,
      'overtimeRate': overtimeRate,
      'sickPayRate': sickPayRate,
      'notes': notes,
    };
  }

  factory WorkShift.fromJson(Map<String, dynamic> json) {
    return WorkShift(
      id: json['id'],
      date: DateTime.parse(json['date']),
      startTime: TimeOfDay(
        hour: json['startHour'],
        minute: json['startMinute'],
      ),
      endTime: TimeOfDay(hour: json['endHour'], minute: json['endMinute']),
      totalHours: json['totalHours'],
      estimatedPay: json['estimatedPay'],
      isCompleted: json['isCompleted'],
      type: json['type'] ?? 'work',
      overtimeRate: (json['overtimeRate'] ?? 1.0).toDouble(),
      sickPayRate: (json['sickPayRate'] ?? 0.8).toDouble(),
      notes: json['notes'] ?? '',
    );
  }
}
