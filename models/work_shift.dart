import 'package:flutter/material.dart';

class WorkShift {
  final String id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double totalHours;
  final double regularHours;
  final double nightHours;
  final double estimatedPay;
  final bool isCompleted;
  final String type; // NOWE: 'work' (Praca), 'off' (Wolne), 'sick' (L4)

  WorkShift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalHours,
    required this.regularHours,
    required this.nightHours,
    required this.estimatedPay,
    required this.isCompleted,
    required this.type,
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
      'regularHours': regularHours,
      'nightHours': nightHours,
      'estimatedPay': estimatedPay,
      'isCompleted': isCompleted,
      'type': type,
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
      regularHours: json['regularHours'],
      nightHours: json['nightHours'],
      estimatedPay: json['estimatedPay'],
      isCompleted: json['isCompleted'],
      type: json['type'] ?? 'work', // Ochrona starych danych!
    );
  }
}
