import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

export 'calendar.dart';
export 'cards.dart';

/// Rounded white card used throughout the app.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.bordered = false, this.color, this.radius = 16});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool bordered;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: c.border, width: 1) : null,
        boxShadow: bordered ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content),
    );
  }
}

/// Small rounded square with an icon (settings rows, quick actions).
class ColoredIconTile extends StatelessWidget {
  const ColoredIconTile({super.key, required this.icon, required this.background, this.foreground = Colors.white, this.size = 30, this.radius = 8});
  final IconData icon;
  final Color background, foreground;
  final double size, radius;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
    child: Icon(icon, color: foreground, size: size * 0.6),
  );
}

/// A row inside a grouped settings section.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.value,
    this.onTap,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.destructive = false,
  });
  final String title;
  final String? value, subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron, destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (context, box) {
                final titleCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, color: destructive ? c.weekend : c.textPrimary)),
                    if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 14, color: c.textSecondary)),
                  ],
                );
                return Row(
                  children: [
                    if (icon != null) ...[ColoredIconTile(icon: icon!, background: iconColor ?? c.primary, size: 30), const SizedBox(width: 14)],
                    // Title takes its natural width (max 62%); the value gets the rest.
                    if (value != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
                        child: titleCol,
                      )
                    else
                      Expanded(child: titleCol),
                    if (value != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 17, color: c.textSecondary),
                        ),
                      ),
                    ],
                    ?trailing,
                    if (showChevron && onTap != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.chevron_right_rounded, color: c.textSecondary.withValues(alpha: 0.6), size: 26),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded surface that hosts ListTiles (a Material, so ink and tile backgrounds render correctly).
class SurfaceGroup extends StatelessWidget {
  const SurfaceGroup({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Material(color: context.colors.surface, borderRadius: BorderRadius.circular(14), clipBehavior: Clip.antiAlias, child: child);
}

/// iOS-style grouped list section.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.header, this.indentDividers = 60});
  final List<Widget> children;
  final String? header;
  final double indentDividers;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 16, 6),
            child: Text(header!, style: TextStyle(fontSize: 13, color: c.textSecondary, letterSpacing: 0.2)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SurfaceGroup(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) Divider(indent: indentDividers, height: 0.6)],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS-like segmented control.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({super.key, required this.segments, required this.value, required this.onChanged, this.expand = false});
  final Map<T, String> segments;
  final bool expand;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.segmentBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final e in segments.entries)
            Flexible(
              fit: expand ? FlexFit.tight : FlexFit.loose,
              child: Semantics(
                selected: e.key == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: e.key == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: e.key == value ? [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2))] : null,
                    ),
                    alignment: expand ? Alignment.center : null,
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w500, color: c.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.icon = Icons.inbox_outlined, this.action});
  final String title;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: c.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: c.weekend),
            const SizedBox(height: 12),
            Text(l.errorTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              errorText(context, error),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
            if (onRetry != null) ...[const SizedBox(height: 16), OutlinedButton(onPressed: onRetry, child: Text(l.retry))],
          ],
        ),
      ),
    );
  }
}

/// Maps API error codes to localized messages.
String errorText(BuildContext context, Object e) {
  final l = AppLocalizations.of(context);
  final a = ApiException.from(e);
  switch (a.code) {
    case 'SLOT_TAKEN':
      return l.slotTaken;
    case 'VERSION_CONFLICT':
      return l.versionConflict;
    case 'SUBSCRIPTION_REQUIRED':
      return l.subscriptionRequired;
  }
  return a.message;
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context, e)), behavior: SnackBarBehavior.floating));
}

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.rows = 4, this.height = 64});
  final int rows;
  final double height;
  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              for (var i = 0; i < widget.rows; i++)
                Container(
                  height: widget.height,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders loading / error / data for an AsyncValue consistently.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingSkeleton(),
      error: (e, _) => ErrorState(error: e, onRetry: onRetry),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, String? message, required String confirmLabel, bool destructive = false}) async {
  final l = AppLocalizations.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: destructive ? context.colors.weekend : null, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  return r ?? false;
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.name, this.size = 64, this.badge = false, this.logo = false});
  final String? name;
  final double size;
  final bool badge, logo;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: logo ? Colors.white : const Color(0xFFD9D9DE),
              border: Border.all(color: logo ? const Color(0xFFE6E6EA) : Colors.white, width: logo ? 3 : 2),
            ),
            child: logo
                ? Icon(Icons.auto_awesome_rounded, color: c.textSecondary, size: size * 0.42)
                : Icon(Icons.person_rounded, color: Colors.white, size: size * 0.78),
          ),
          if (badge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.48,
                height: size * 0.48,
                decoration: BoxDecoration(
                  color: c.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(Icons.notifications_rounded, color: Colors.white, size: size * 0.28),
              ),
            ),
        ],
      ),
    );
  }
}
