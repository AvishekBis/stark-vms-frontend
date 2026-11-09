import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// A form field that picks a calendar date with the Material date picker.
///
/// [errorText] shows a server error under the field (like `errorText` on a
/// TextFormField); the [validator] runs on form validation.
class DateFormField extends FormField<DateTime> {
  DateFormField({
    super.key,
    required String label,
    required DateTime firstDate,
    required DateTime lastDate,
    super.initialValue,
    super.validator,
    ValueChanged<DateTime?>? onChanged,
    String? errorText,
    String? helperText,
    bool clearable = false,
    super.enabled,
  }) : super(
         builder: (field) {
           final context = field.context;
           Future<void> pick() async {
             final current = field.value;
             final initial = current == null
                 ? _clamp(DateTime.now(), firstDate, lastDate)
                 : _clamp(current, firstDate, lastDate);
             final picked = await showDatePicker(
               context: context,
               initialDate: initial,
               firstDate: firstDate,
               lastDate: lastDate,
               helpText: label,
             );
             if (picked != null) {
               field.didChange(picked);
               onChanged?.call(picked);
             }
           }

           final value = field.value;
           return InkWell(
             onTap: field.widget.enabled ? pick : null,
             child: InputDecorator(
               isEmpty: value == null,
               decoration: InputDecoration(
                 labelText: label,
                 helperText: helperText,
                 errorText: field.errorText ?? errorText,
                 errorMaxLines: 2,
                 enabled: field.widget.enabled,
                 suffixIcon: clearable && value != null
                     ? IconButton(
                         tooltip: 'Clear date',
                         icon: const Icon(Icons.clear),
                         onPressed: () {
                           field.didChange(null);
                           onChanged?.call(null);
                         },
                       )
                     : const Icon(Icons.calendar_today_outlined),
               ),
               child: Text(value == null ? '' : Formatters.date(value)),
             ),
           );
         },
       );

  static DateTime _clamp(DateTime value, DateTime first, DateTime last) {
    if (value.isBefore(first)) {
      return first;
    }
    if (value.isAfter(last)) {
      return last;
    }
    return value;
  }
}
