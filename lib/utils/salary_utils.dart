/// Salary range shared by forms, lists, the map and the admin panel.
///
/// Both bounds are optional: no bounds means "by agreement", a single bound
/// is a fixed salary, and two different bounds form a range.
class SalaryRange {
  final int? min;
  final int? max;

  const SalaryRange({this.min, this.max});

  static const SalaryRange empty = SalaryRange();

  bool get isEmpty => min == null && max == null;

  /// Lowest known amount (the single value when only one bound is set).
  int? get lower => min ?? max;

  /// Highest known amount (the single value when only one bound is set).
  int? get upper => max ?? min;

  bool get isRange => min != null && max != null && min != max;

  /// Amount stored in the legacy `salary_amount` column.
  int get amount => lower ?? 0;

  @override
  bool operator ==(Object other) =>
      other is SalaryRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'SalaryRange($min, $max)';
}

int? _positiveInt(dynamic value) {
  if (value == null) return null;
  final number = value is num
      ? value
      : num.tryParse(value.toString().trim().replaceAll(',', '.'));
  if (number == null || number <= 0) return null;
  return number.round();
}

SalaryRange _ordered(int? a, int? b) {
  if (a != null && b != null && a > b) return SalaryRange(min: b, max: a);
  return SalaryRange(min: a, max: b);
}

final RegExp _rangePattern = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*[-\u2013\u2014]\s*(\d+(?:[.,]\d+)?)',
);
final RegExp _numberPattern = RegExp(r'\d+(?:[.,]\d+)?');

/// Parses free text such as "600-2000", "600 - 900 AZN" or "750".
SalaryRange parseSalaryText(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return SalaryRange.empty;
  final range = _rangePattern.firstMatch(value);
  if (range != null) {
    return _ordered(_positiveInt(range.group(1)), _positiveInt(range.group(2)));
  }
  final single = _numberPattern.firstMatch(value);
  if (single != null) return SalaryRange(min: _positiveInt(single.group(0)));
  return SalaryRange.empty;
}

/// Reads the range from a job row: `salary_min`/`salary_max` first, then the
/// `salary` text, then the legacy `salary_amount`.
SalaryRange parseSalary(Map<String, dynamic> job) {
  final min = _positiveInt(job['salary_min']);
  final max = _positiveInt(job['salary_max']);
  if (min != null || max != null) return _ordered(min, max);

  final fromText = parseSalaryText(job['salary']?.toString());
  if (!fromText.isEmpty) return fromText;

  final amount = _positiveInt(job['salary_amount']);
  return amount == null ? SalaryRange.empty : SalaryRange(min: amount);
}

/// Text stored in the `salary` column ("600 - 2000 AZN", "600 AZN") or null.
String? formatSalaryText(SalaryRange range) {
  if (range.isEmpty) return null;
  if (range.isRange) return '${range.min} - ${range.max} AZN';
  return '${range.lower} AZN';
}

/// Text shown to users: "600 - 2000 ₼", "600 ₼" or [empty].
String formatSalaryDisplay(SalaryRange range, {String empty = 'Razılaşma ilə'}) {
  if (range.isEmpty) return empty;
  if (range.isRange) return '${range.min} - ${range.max} ₼';
  return '${range.lower} ₼';
}

/// Short text for map markers: "600-2000 ₼", "600 ₼" or "0 ₼".
String formatSalaryCompact(SalaryRange range) {
  if (range.isEmpty) return '0 ₼';
  if (range.isRange) return '${range.min}-${range.max} ₼';
  return '${range.lower} ₼';
}

/// Whether the job's salary overlaps the filter interval. A filter end of
/// null means "no upper limit". Jobs without salary count as 0.
bool salaryOverlaps(SalaryRange range, {required num filterMin, num? filterMax}) {
  final low = range.lower ?? 0;
  final high = range.upper ?? 0;
  if (high < filterMin) return false;
  if (filterMax != null && low > filterMax) return false;
  return true;
}

/// Values for the database write. Empty salary writes nulls (by agreement).
Map<String, dynamic> salaryPayload(SalaryRange range) {
  return <String, dynamic>{
    'salary_min': range.min,
    'salary_max': range.max,
    'salary_amount': range.isEmpty ? 0 : range.amount,
    'salary': formatSalaryText(range),
  };
}

/// Validates the two form fields. Returns an error message or null.
String? validateSalaryInputs(String? minText, String? maxText,
    {required String invalidMessage, required String orderMessage}) {
  final minValue = minText?.trim() ?? '';
  final maxValue = maxText?.trim() ?? '';
  int? minNumber;
  int? maxNumber;
  if (minValue.isNotEmpty) {
    minNumber = int.tryParse(minValue);
    if (minNumber == null) return invalidMessage;
  }
  if (maxValue.isNotEmpty) {
    maxNumber = int.tryParse(maxValue);
    if (maxNumber == null) return invalidMessage;
  }
  if (minNumber != null && maxNumber != null && minNumber > maxNumber) {
    return orderMessage;
  }
  return null;
}

/// Builds the range from the two form fields (empty or 0 means not set).
SalaryRange salaryFromInputs(String? minText, String? maxText) {
  return SalaryRange(
    min: _positiveInt(minText),
    max: _positiveInt(maxText),
  );
}
