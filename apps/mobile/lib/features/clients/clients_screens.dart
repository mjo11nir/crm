import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});
  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = ref.watch(clientsProvider(_q));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.clients),
        actions: [
          IconButton(
            tooltip: l.newClient,
            icon: Icon(Icons.person_add_alt_1_rounded, color: c.primary),
            onPressed: () async {
              await context.push('/client-form');
              ref.invalidate(clientsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.search, isDense: true),
              onChanged: (t) => setState(() => _q = t.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(clientsProvider),
              child: AsyncView<({List<Client> items, int total})>(
                value: v,
                onRetry: () => ref.invalidate(clientsProvider),
                data: (r) => r.items.isEmpty
                    ? ListView(
                        children: [EmptyState(title: l.nothingHere, icon: Icons.people_outline_rounded)],
                      )
                    : ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                            child: Text(l.clientsCount(r.total), style: TextStyle(color: c.textSecondary)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SurfaceGroup(
                              child: Column(
                                children: [for (final cl in r.items) ClientCard(client: cl, onTap: () => context.go('/more/clients/${cl.id}'))],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key, required this.clientId});
  final String clientId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    final v = ref.watch(clientProfileProvider(clientId));
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l.save,
            icon: Icon(Icons.edit_rounded, color: c.primary),
            onPressed: () async {
              await context.push('/client-form?id=$clientId');
              ref.invalidate(clientProfileProvider(clientId));
            },
          ),
        ],
      ),
      body: AsyncView<ClientProfile>(
        value: v,
        onRetry: () => ref.invalidate(clientProfileProvider(clientId)),
        data: (p) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Center(child: Avatar(size: 88, name: p.client.fullName)),
            const SizedBox(height: 10),
            Center(
              child: Text(p.client.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ),
            if (p.client.phone != null)
              Center(
                child: Text(p.client.phone!, style: TextStyle(color: c.textSecondary, fontSize: 16)),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(label: l.visits, value: '${p.visits}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(label: l.totalSpent, value: formatMoney(p.totalSpentMinor, currency, locale, compact: true)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(label: l.statusNO_SHOW, value: '${p.noShows}'),
                  ),
                ],
              ),
            ),
            SettingsGroup(
              indentDividers: 16,
              children: [
                SettingRow(title: l.lastVisit, value: p.lastVisit == null ? '—' : DateFormat('d MMM y', locale).format(toBusinessLocal(p.lastVisit!))),
                SettingRow(
                  title: l.nextAppointment,
                  value: p.next == null ? '—' : DateFormat('d MMM, HH:mm', locale).format(toBusinessLocal(p.next!.startsAt)),
                  onTap: p.next == null ? null : () => context.push('/appointment/${p.next!.id}'),
                ),
                if (p.client.email != null) SettingRow(title: l.email, value: p.client.email),
                if (p.client.birthday != null) SettingRow(title: l.birthday, value: p.client.birthday),
                if (p.client.discountPercent > 0) SettingRow(title: l.discountPercent, value: '${p.client.discountPercent}%'),
                if (p.client.notes != null && p.client.notes!.isNotEmpty) SettingRow(title: l.notes, subtitle: p.client.notes),
              ],
            ),
            SettingsGroup(
              indentDividers: 16,
              children: [
                SettingRow(
                  title: l.createAppointment,
                  icon: Icons.add_rounded,
                  iconColor: c.primary,
                  onTap: () => context.push('/appointment/new?clientId=$clientId'),
                ),
                SettingRow(
                  title: l.archive,
                  destructive: true,
                  showChevron: false,
                  onTap: () async {
                    if (!await confirmDialog(context, title: l.archive, confirmLabel: l.archive, destructive: true)) return;
                    try {
                      await ref.read(repositoryProvider).archiveClient(ref.read(sessionProvider).value!.businessId, clientId, true);
                      ref.invalidate(clientsProvider);
                      if (context.mounted) context.pop();
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ],
            ),
            if (p.appointments.isNotEmpty)
              SettingsGroup(
                header: l.history.toUpperCase(),
                indentDividers: 16,
                children: [
                  for (final a in p.appointments.take(50))
                    SettingRow(
                      title: DateFormat('d MMM y, HH:mm', locale).format(toBusinessLocal(a.startsAt)),
                      subtitle: a.serviceNames.join(', '),
                      trailing: StatusChip(status: a.status),
                      onTap: () => context.push('/appointment/${a.id}'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Column(
      children: [
        FittedBox(
          child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}

class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.clientId});
  final String? clientId;
  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _notes = TextEditingController(),
      _birthday = TextEditingController(),
      _tags = TextEditingController();
  int _discount = 0;
  bool _consent = false, _busy = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.clientId == null) {
      _loaded = true;
    } else {
      ref
          .read(repositoryProvider)
          .clientProfile(ref.read(sessionProvider).value!.businessId, widget.clientId!)
          .then((p) {
            final cl = p.client;
            _name.text = cl.fullName;
            _phone.text = cl.phone ?? '';
            _email.text = cl.email ?? '';
            _notes.text = cl.notes ?? '';
            _birthday.text = cl.birthday ?? '';
            _tags.text = cl.tags.join(', ');
            _discount = cl.discountPercent;
            if (mounted) setState(() => _loaded = true);
          })
          .catchError((Object e) {
            if (mounted) showError(context, e);
          });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'fullName': _name.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      if (_birthday.text.trim().isNotEmpty) 'birthday': _birthday.text.trim(),
      'tags': [
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      'discountPercent': _discount,
      'marketingConsent': _consent,
    };
    try {
      final repo = ref.read(repositoryProvider);
      final b = ref.read(sessionProvider).value!.businessId;
      widget.clientId == null ? await repo.createClient(b, body) : await repo.updateClient(b, widget.clientId!, body);
      ref.invalidate(clientsProvider);
      ref.invalidate(dashboardProvider);
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
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(l.cancel, style: TextStyle(color: c.primary)),
        ),
        title: Text(widget.clientId == null ? l.newClient : l.client),
      ),
      body: !_loaded
          ? const LoadingSkeleton()
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l.fullName),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: l.phone),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: l.email),
                    validator: (v) => (v == null || v.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? null : l.invalidEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _birthday,
                    readOnly: true,
                    decoration: InputDecoration(labelText: l.birthday),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime(1995), firstDate: DateTime(1920), lastDate: DateTime.now());
                      if (d != null) _birthday.text = isoDate(d);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tags,
                    decoration: InputDecoration(labelText: l.tags),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l.notes),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _discount,
                    decoration: InputDecoration(labelText: l.discountPercent),
                    items: [
                      for (final p in {0, 5, 10, 15, 20, 25, 30, 50, _discount}) DropdownMenuItem(value: p, child: Text('$p%')),
                    ],
                    onChanged: (v) => setState(() => _discount = v!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    activeThumbColor: c.primary,
                    title: Text(l.marketingConsent),
                    onChanged: (v) => setState(() => _consent = v),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(label: l.save, loading: _busy, onPressed: _save),
                ],
              ),
            ),
    );
  }
}
