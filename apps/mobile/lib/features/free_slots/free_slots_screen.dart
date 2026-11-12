import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

const freeSlotThemes = [Color(0xFF8E2DE2), Color(0xFFEB3485), Color(0xFF078EA7), Color(0xFF28B84A), Color(0xFFE9A21F), Color(0xFF222222)];

typedef FreeSlotsArgs = ({String from, String to, String? serviceId, String? locationId});

final freeSlotsProvider = FutureProvider.autoDispose.family<FreeSlots, FreeSlotsArgs>(
  (ref, a) => ref
      .read(repositoryProvider)
      .freeSlots(ref.read(sessionProvider).value!.businessId, from: a.from, to: a.to, serviceId: a.serviceId, locationId: a.locationId),
);

/// Свободные окна (reference screenshots 3 & 5).
class FreeSlotsScreen extends ConsumerStatefulWidget {
  const FreeSlotsScreen({super.key});
  @override
  ConsumerState<FreeSlotsScreen> createState() => _FreeSlotsScreenState();
}

class _FreeSlotsScreenState extends ConsumerState<FreeSlotsScreen> {
  int _tab = 0;
  late DateTimeRange _range = DateTimeRange(start: businessToday(), end: businessToday().add(const Duration(days: 13)));
  bool _asImage = true;
  Color _theme = freeSlotThemes.first;
  String? _serviceId;
  String? _locationId;
  bool _sharing = false;
  final _cardKey = GlobalKey();

  Future<void> _share(FreeSlots s) async {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    setState(() => _sharing = true);
    try {
      final text = StringBuffer('${s.name}\n${l.freeTimeForBooking}\n');
      for (final d in s.days) {
        text.writeln('${DateFormat('EE, d MMM', locale).format(DateTime.parse(d.date))}: ${d.times.join('  ')}');
      }
      text.writeln('\n${l.bookingLink}: ${s.bookingUrl}');
      if (_asImage) {
        final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes!.buffer.asUint8List(), mimeType: 'image/png', name: 'free-slots.png')],
            text: s.bookingUrl,
          ),
        );
      } else {
        await SharePlus.instance.share(ShareParams(text: text.toString()));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final business = ref.watch(businessProvider).value;
    final services = ref.watch(servicesProvider).value?.where((s) => s.isActive).toList() ?? const <Service>[];
    final location = business?.locations.where((x) => x.id == _locationId).firstOrNull ?? business?.locations.firstOrNull;
    final args = (from: isoDate(_range.start), to: isoDate(_range.end), serviceId: _serviceId, locationId: location?.id);
    final slots = ref.watch(freeSlotsProvider(args));
    final df = DateFormat('d MMM', locale);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.background,
        leadingWidth: 110,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(l.close, style: TextStyle(color: c.primary, fontSize: 18)),
        ),
        title: Text(l.freeSlots, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: c.background,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedControl<int>(expand: true, segments: {0: l.share, 1: l.findAndBook}, value: _tab, onChanged: (v) => setState(() => _tab = v)),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Text(l.freeSlotsHint, style: TextStyle(color: c.textSecondary, fontSize: 15)),
          ),
          Container(
            color: c.surface,
            child: Column(
              children: [
                const Divider(height: 1),
                SettingRow(
                  title: location?.name ?? '—',
                  subtitle: location?.address,
                  onTap: (business?.locations.length ?? 0) > 1
                      ? () async {
                          final id = await showModalBottomSheet<String>(
                            context: context,
                            builder: (_) => ListView(
                              shrinkWrap: true,
                              children: [
                                for (final x in business!.locations)
                                  ListTile(
                                    title: Text(x.name),
                                    subtitle: x.address == null ? null : Text(x.address!),
                                    onTap: () => Navigator.pop(context, x.id),
                                  ),
                              ],
                            ),
                          );
                          if (id != null) setState(() => _locationId = id);
                        }
                      : () => context.go('/more/work-schedule'),
                ),
                const Divider(height: 1, indent: 16),
                if (services.isNotEmpty) ...[
                  SettingRow(
                    title: l.services,
                    value: services.where((s) => s.id == _serviceId).firstOrNull?.name ?? l.minutesShort(120),
                    onTap: () async {
                      final id = await showModalBottomSheet<String>(
                        context: context,
                        builder: (_) => ListView(
                          shrinkWrap: true,
                          children: [
                            for (final s in services)
                              ListTile(title: Text(s.name), subtitle: Text(l.minutesShort(s.durationMinutes)), onTap: () => Navigator.pop(context, s.id)),
                          ],
                        ),
                      );
                      if (id != null) setState(() => _serviceId = id);
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                ],
                SettingRow(
                  title: l.period,
                  value: '${df.format(_range.start)} - ${df.format(_range.end)}',
                  onTap: () async {
                    final r = await showDateRangePicker(
                      context: context,
                      firstDate: businessToday(),
                      lastDate: businessToday().add(const Duration(days: 180)),
                      initialDateRange: _range,
                    );
                    if (r != null) {
                      setState(() => _range = r.duration.inDays > 62 ? DateTimeRange(start: r.start, end: r.start.add(const Duration(days: 62))) : r);
                    }
                  },
                ),
                if (_tab == 0) ...[
                  const Divider(height: 1, indent: 16),
                  SettingRow(title: l.view, value: _asImage ? l.viewImage : l.viewText, onTap: () => setState(() => _asImage = !_asImage)),
                  const Divider(height: 1, indent: 16),
                  SettingRow(
                    title: l.colorTheme,
                    trailing: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_theme, Color.lerp(_theme, Colors.white, 0.35)!],
                        ),
                      ),
                    ),
                    onTap: () async {
                      final col = await showModalBottomSheet<Color>(
                        context: context,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final t in freeSlotThemes)
                                GestureDetector(
                                  onTap: () => Navigator.pop(context, t),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(color: t, borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (col != null) setState(() => _theme = col);
                    },
                  ),
                ],
                const Divider(height: 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 26, 16, 8),
            child: Text(l.freeSlotsByDay, style: TextStyle(fontSize: 14, color: c.textSecondary)),
          ),
          const Divider(height: 1),
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: AsyncView<FreeSlots>(
              value: slots,
              onRetry: () => ref.invalidate(freeSlotsProvider),
              data: (s) => _tab == 0
                  ? Column(
                      children: [
                        RepaintBoundary(
                          key: _cardKey,
                          child: AvailabilityCard(slots: s, themeColor: _theme, locale: locale),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(label: l.send, loading: _sharing, onPressed: () => _share(s)),
                      ],
                    )
                  : _FindAndBook(slots: s, locale: locale),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindAndBook extends StatelessWidget {
  const _FindAndBook({required this.slots, required this.locale});
  final FreeSlots slots;
  final String locale;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    if (slots.days.isEmpty) return EmptyState(title: l.noFreeTime);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in slots.days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(DateFormat('EEEE, d MMMM', locale).format(DateTime.parse(d.date)), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in d.times)
                ActionChip(
                  label: Text(t),
                  labelStyle: TextStyle(color: c.primary),
                  onPressed: () {
                    final p = t.split(':');
                    final dt = DateTime.parse(d.date);
                    final start = fromBusinessLocal(DateTime(dt.year, dt.month, dt.day, int.parse(p[0]), int.parse(p[1])));
                    context.push('/appointment/new?date=${d.date}&start=${start.toIso8601String()}');
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(l.createAppointment, style: TextStyle(color: c.textSecondary, fontSize: 13)),
      ],
    );
  }
}
