import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale_controller.dart';
import 'app_strings.dart';

class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appLocaleControllerProvider);
    final strings = AppStrings.of(context);

    if (compact) {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => controller.toggle(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
            ),
          ),
          child: Text(
            controller.isFrench ? '🇫🇷 FR · EN' : '🇬🇧 EN · FR',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _showSheet(context, controller),
      icon: const Icon(Icons.language_rounded, size: 18),
      label: Text(strings.language),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showSheet(BuildContext context, AppLocaleController controller) {
    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.chooseLanguage,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _LanguageCard(
                title: strings.french,
                subtitle: 'Français',
                leading: '🇫🇷',
                selected: controller.isFrench,
                onTap: () async {
                  await controller.setLocale(AppLocaleController.frenchLocale);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _LanguageCard(
                title: strings.english,
                subtitle: 'English',
                leading: '🇬🇧',
                selected: !controller.isFrench,
                onTap: () async {
                  await controller.setLocale(AppLocaleController.englishLocale);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Text(leading, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
