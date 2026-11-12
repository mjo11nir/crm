import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    final v = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.servicesAndProducts),
        actions: [
          IconButton(
            tooltip: l.newService,
            icon: Icon(Icons.add_rounded, color: c.primary),
            onPressed: () => context.push('/service-form'),
          ),
        ],
      ),
      body: AsyncView<List<Service>>(
        value: v,
        onRetry: () => ref.invalidate(servicesProvider),
        data: (list) => list.isEmpty
            ? EmptyState(
                title: l.nothingHere,
                icon: Icons.room_service_outlined,
                action: TextButton(onPressed: () => context.push('/service-form'), child: Text(l.newService)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SurfaceGroup(
                      child: Column(
                        children: [
                          for (final s in list)
                            ServiceCard(service: s, currency: currency, locale: locale, onTap: () => context.push('/service-form?id=${s.id}')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.serviceId});
  final String? serviceId;
  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _desc = TextEditingController(), _price = TextEditingController(), _deposit = TextEditingController(text: '0');
  int _duration = 60, _buffer = 0;
  bool _online = true, _active = true, _busy = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(servicesProvider).value?.where((x) => x.id == widget.serviceId).firstOrNull;
    if (s != null) {
      _name.text = s.name;
      _desc.text = s.description ?? '';
      _price.text = (s.priceMinor / 100).toStringAsFixed(2);
      _deposit.text = (s.depositMinor / 100).toStringAsFixed(2);
      _duration = s.durationMinutes;
      _buffer = s.bufferMinutes;
      _online = s.onlineBookable;
      _active = s.isActive;
    }
  }

  int? _minor(String t) {
    final v = double.tryParse(t.replaceAll(',', '.'));
    return v == null || v < 0 ? null : (v * 100).round();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'name': _name.text.trim(),
      if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      'durationMinutes': _duration,
      'bufferMinutes': _buffer,
      'priceMinor': _minor(_price.text),
      'depositMinor': _minor(_deposit.text) ?? 0,
      'onlineBookable': _online,
      'isActive': _active,
    };
    try {
      final repo = ref.read(repositoryProvider);
      final b = ref.read(sessionProvider).value!.businessId;
      widget.serviceId == null ? await repo.createService(b, body) : await repo.updateService(b, widget.serviceId!, body);
      ref.invalidate(servicesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(l.cancel, style: TextStyle(color: c.primary)),
        ),
        title: Text(widget.serviceId == null ? l.newService : l.services),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.name),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.notes),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${l.price}, $currency'),
              validator: (v) => _minor(v ?? '') == null ? l.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deposit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${l.deposit}, $currency'),
              validator: (v) => (_minor(v ?? '0') ?? 0) > (_minor(_price.text) ?? 0) ? l.price : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: InputDecoration(labelText: l.duration),
              items: [
                for (final m in {15, 30, 45, 60, 75, 90, 105, 120, 150, 180, 240, _duration}) DropdownMenuItem(value: m, child: Text(l.minutesShort(m))),
              ],
              onChanged: (v) => setState(() => _duration = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _buffer,
              decoration: InputDecoration(labelText: l.bufferMinutes),
              items: [
                for (final m in {0, 5, 10, 15, 20, 30, 45, 60, _buffer}) DropdownMenuItem(value: m, child: Text('$m')),
              ],
              onChanged: (v) => setState(() => _buffer = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _online,
              activeThumbColor: c.primary,
              title: Text(l.onlineBookable),
              onChanged: (v) => setState(() => _online = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              activeThumbColor: c.primary,
              title: Text(l.active),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: l.save, loading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
