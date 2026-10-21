import 'package:flutter/material.dart';

/// A top-level section of the app, shown in the navigation bar or rail.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

/// Top-level sections in navigation order. The router creates one branch
/// per entry, in the same order.
const appDestinations = [
  AppDestination(
    label: 'Quizzes',
    path: '/quizzes',
    icon: Icons.quiz_outlined,
    selectedIcon: Icons.quiz,
  ),
  AppDestination(
    label: 'Flashcards',
    path: '/flashcards',
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
  ),
  AppDestination(
    label: 'Stats',
    path: '/stats',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
  ),
  AppDestination(
    label: 'Catalog',
    path: '/catalog',
    icon: Icons.travel_explore_outlined,
    selectedIcon: Icons.travel_explore,
  ),
  AppDestination(
    label: 'Settings',
    path: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];
