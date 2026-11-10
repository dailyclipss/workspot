import 'package:flutter/material.dart';

import '../models/category.dart';

const Map<String, IconData> _categoryIcons = {
  'restaurant': Icons.restaurant,
  'soup_kitchen': Icons.soup_kitchen,
  'local_cafe': Icons.local_cafe,
  'storefront': Icons.storefront,
  'point_of_sale': Icons.point_of_sale,
  'warehouse': Icons.warehouse,
  'delivery_dining': Icons.delivery_dining,
  'directions_car': Icons.directions_car,
  'cleaning_services': Icons.cleaning_services,
  'security': Icons.security,
  'support_agent': Icons.support_agent,
  'badge': Icons.badge,
  'account_balance': Icons.account_balance,
  'business_center': Icons.business_center,
  'groups': Icons.groups,
  'campaign': Icons.campaign,
  'brush': Icons.brush,
  'code': Icons.code,
  'engineering': Icons.engineering,
  'construction': Icons.construction,
  'handyman': Icons.handyman,
  'car_repair': Icons.car_repair,
  'factory': Icons.factory,
  'hotel': Icons.hotel,
  'content_cut': Icons.content_cut,
  'school': Icons.school,
  'medical_services': Icons.medical_services,
  'gavel': Icons.gavel,
  'agriculture': Icons.agriculture,
  'local_shipping': Icons.local_shipping,
  'fitness_center': Icons.fitness_center,
  'videocam': Icons.videocam,
  'translate': Icons.translate,
  'child_care': Icons.child_care,
  'more_horiz': Icons.more_horiz,
};

/// Material icon for a category's `icon` column; Icons.work when unknown.
IconData iconForCategory(JobCategory? category) {
  final name = category?.icon;
  if (name == null || name.isEmpty) return Icons.work;
  return _categoryIcons[name] ?? Icons.work;
}
