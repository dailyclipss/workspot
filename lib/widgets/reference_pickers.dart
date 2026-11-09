import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/district.dart';
import '../services/app_language.dart';
import '../services/reference_data_service.dart';
import '../utils/category_icons.dart';
import '../utils/text_normalize.dart';

/// Result of a picker: [value] is null when the user chose "clear/all".
/// The picker itself returns null when it was dismissed.
class PickResult<T> {
  final T? value;
  const PickResult(this.value);
}

/// Filters categories by a normalized query over all three languages.
List<JobCategory> filterCategories(List<JobCategory> all, String query) {
  final q = normalizeAz(query);
  if (q.isEmpty) return all;
  return all
      .where((c) => [c.nameAz, c.nameRu, c.nameEn]
          .any((name) => normalizeAz(name).contains(q)))
      .toList();
}

List<District> filterDistricts(List<District> all, String query) {
  final q = normalizeAz(query);
  if (q.isEmpty) return all;
  return all
      .where((d) => [d.nameAz, d.nameRu, d.nameEn]
          .any((name) => normalizeAz(name).contains(q)))
      .toList();
}

Future<PickResult<JobCategory>?> showCategoryPicker(
  BuildContext context, {
  int? selectedId,
  bool allowAll = false,
}) {
  return showModalBottomSheet<PickResult<JobCategory>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategorySheet(selectedId: selectedId, allowAll: allowAll),
  );
}

Future<District?> showDistrictPicker(BuildContext context, {int? selectedId}) {
  return showModalBottomSheet<District>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DistrictSheet(selectedId: selectedId),
  );
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final ValueChanged<String> onQuery;
  final Widget child;

  const _SheetFrame(
      {required this.title, required this.onQuery, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: onQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: appLang.translate('ref_search'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: PrimaryScrollController(
                controller: controller,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final int? selectedId;
  final bool allowAll;
  const _CategorySheet({this.selectedId, this.allowAll = false});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final lang = appLang.currentLanguage;
    final items = filterCategories(
        ReferenceDataService.instance.categories, _query);
    final showAll = widget.allowAll && _query.trim().isEmpty;
    return _SheetFrame(
      title: appLang.translate('ref_category_title'),
      onQuery: (q) => setState(() => _query = q),
      child: items.isEmpty
          ? Center(child: Text(appLang.translate('ref_no_results')))
          : ListView.builder(
              itemCount: items.length + (showAll ? 1 : 0),
              itemBuilder: (context, index) {
                if (showAll && index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.apps),
                    title: Text(appLang.translate('ref_all_categories')),
                    selected: widget.selectedId == null,
                    onTap: () => Navigator.pop(
                        context, const PickResult<JobCategory>(null)),
                  );
                }
                final c = items[index - (showAll ? 1 : 0)];
                return ListTile(
                  leading: Icon(iconForCategory(c)),
                  title: Text(c.localizedName(lang)),
                  selected: c.id == widget.selectedId,
                  trailing:
                      c.id == widget.selectedId ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, PickResult(c)),
                );
              },
            ),
    );
  }
}

class _DistrictSheet extends StatefulWidget {
  final int? selectedId;
  const _DistrictSheet({this.selectedId});

  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final lang = appLang.currentLanguage;
    final items =
        filterDistricts(ReferenceDataService.instance.districts, _query);
    final groups = <MapEntry<String, String>>[
      MapEntry(District.kindRayon, appLang.translate('ref_group_rayon')),
      MapEntry(District.kindArea, appLang.translate('ref_group_area')),
      MapEntry(District.kindCity, appLang.translate('ref_group_city')),
    ];
    final children = <Widget>[];
    for (final group in groups) {
      final inGroup = items.where((d) => d.kind == group.key).toList();
      if (inGroup.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(group.value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      ));
      for (final d in inGroup) {
        children.add(ListTile(
          title: Text(d.localizedName(lang)),
          selected: d.id == widget.selectedId,
          trailing:
              d.id == widget.selectedId ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(context, d),
        ));
      }
    }
    return _SheetFrame(
      title: appLang.translate('ref_district_title'),
      onQuery: (q) => setState(() => _query = q),
      child: children.isEmpty
          ? Center(child: Text(appLang.translate('ref_no_results')))
          : ListView(children: children),
    );
  }
}
