import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

enum DatePreset {
  tous,
  aujourdhui,
  septJours,
  ceMois,
  personnalise,
}

class DateFilterBar extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Function(DateTime? startDate, DateTime? endDate) onDateRangeChanged;

  const DateFilterBar({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.onDateRangeChanged,
  });

  @override
  State<DateFilterBar> createState() => _DateFilterBarState();
}

class _DateFilterBarState extends State<DateFilterBar> {
  DatePreset _currentPreset = DatePreset.tous;
  DateTime? _startDate;
  DateTime? _endDate;

  final DateFormat _displayFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    if (_startDate != null || _endDate != null) {
      _currentPreset = DatePreset.personnalise;
    }
  }

  @override
  void didUpdateWidget(covariant DateFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStartDate != widget.initialStartDate ||
        oldWidget.initialEndDate != widget.initialEndDate) {
      setState(() {
        _startDate = widget.initialStartDate;
        _endDate = widget.initialEndDate;
        if (_startDate == null && _endDate == null) {
          _currentPreset = DatePreset.tous;
        }
      });
    }
  }

  void _applyPreset(DatePreset preset) async {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (preset) {
      case DatePreset.tous:
        start = null;
        end = null;
        break;
      case DatePreset.aujourdhui:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day);
        break;
      case DatePreset.septJours:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        end = DateTime(now.year, now.month, now.day);
        break;
      case DatePreset.ceMois:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0); // Dernier jour du mois
        break;
      case DatePreset.personnalise:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDateRange: _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : DateTimeRange(
                  start: DateTime(now.year, now.month, 1),
                  end: now,
                ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.black,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          start = DateTime(picked.start.year, picked.start.month, picked.start.day);
          end = DateTime(picked.end.year, picked.end.month, picked.end.day);
        } else {
          return; // Annulé, on ne change rien
        }
        break;
    }

    setState(() {
      _currentPreset = preset;
      _startDate = start;
      _endDate = end;
    });

    widget.onDateRangeChanged(start, end);
  }

  void _resetDateFilter() {
    setState(() {
      _currentPreset = DatePreset.tous;
      _startDate = null;
      _endDate = null;
    });
    widget.onDateRangeChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilter = _startDate != null || _endDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Raccourcis horizontaux
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('Toutes dates', DatePreset.tous),
              const SizedBox(width: 8),
              _buildPresetChip('Aujourd\'hui', DatePreset.aujourdhui),
              const SizedBox(width: 8),
              _buildPresetChip('7 jours', DatePreset.septJours),
              const SizedBox(width: 8),
              _buildPresetChip('Ce mois', DatePreset.ceMois),
              const SizedBox(width: 8),
              _buildCustomCalendarChip(),
            ],
          ),
        ),

        // Badge actif de période (si un filtre est sélectionné)
        if (hasActiveFilter) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: Colors.black87),
                const SizedBox(width: 6),
                Text(
                  _formatActiveLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _resetDateFilter,
                  child: const Icon(Icons.cancel_rounded, size: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatActiveLabel() {
    if (_startDate == null && _endDate == null) return '';
    if (_startDate != null && _endDate != null) {
      if (_startDate!.year == _endDate!.year &&
          _startDate!.month == _endDate!.month &&
          _startDate!.day == _endDate!.day) {
        return 'Date : ${_displayFormat.format(_startDate!)}';
      }
      return 'Du ${_displayFormat.format(_startDate!)} au ${_displayFormat.format(_endDate!)}';
    } else if (_startDate != null) {
      return 'À partir du ${_displayFormat.format(_startDate!)}';
    } else {
      return 'Jusqu\'au ${_displayFormat.format(_endDate!)}';
    }
  }

  Widget _buildPresetChip(String label, DatePreset preset) {
    final isSelected = _currentPreset == preset;
    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCalendarChip() {
    final isSelected = _currentPreset == DatePreset.personnalise;
    return GestureDetector(
      onTap: () => _applyPreset(DatePreset.personnalise),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 14,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 4),
            Text(
              'Période',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
