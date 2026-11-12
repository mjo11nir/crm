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

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _busy = false;

  Future<void> _status(String status, {bool confirm = false, String? title}) async {
    final l = AppLocalizations.of(context);
    if (confirm && !await confirmDialog(context, title: title ?? status, confirmLabel: l.confirmAppointment, destructive: true)) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).setStatus(ref.read(sessionProvider).value!.businessId, widget.id, status);
      invalidateCalendar(ref);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Appointment a, String currency) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(appointment: a, currency: currency),
    );
    if (ok == true) invalidateCalendar(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final currency = ref.watch(sessionProvider).value?.membership.currency ?? 'EUR';
    final v = ref.watch(appointmentProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(l.createAppointment.split(' ').last)),
      body: AsyncView<Appointment>(
        value: v,
        onRetry: () => ref.invalidate(appointmentProvider(widget.id)),
        data: (a) {
          final local = toBusinessLocal(a.startsAt);
          final canAct = a.status == 'BOOKED' || a.status == 'CONFIRMED';
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Avatar(size: 64, badge: a.clientPhone != null),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.clientName ?? l.noClient, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                          if (a.clientPhone != null) Text(a.clientPhone!, style: TextStyle(color: c.textSecondary, fontSize: 16)),
                          const SizedBox(height: 6),
                          StatusChip(status: a.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SettingsGroup(
                indentDividers: 16,
                children: [
                  SettingRow(title: l.date, value: toBeginningOfSentenceCase(DateFormat('EEEE, d MMMM y', locale).format(local))),
                  SettingRow(title: l.time, value: '${hhmm(a.startsAt)} – ${hhmm(a.endsAt)}'),
                  SettingRow(title: l.services, value: a.serviceNames.join(', ')),
                  SettingRow(title: l.price, value: formatMoney(a.netPriceMinor, currency, locale)),
                  SettingRow(title: l.balance, value: formatMoney(a.balanceMinor, currency, locale)),
                  if (a.notes != null && a.notes!.isNotEmpty) SettingRow(title: l.notes, subtitle: a.notes),
                  if (a.clientId != null) SettingRow(title: l.client, value: '', onTap: () => context.push('/more/clients/${a.clientId}')),
                ],
              ),
              if (a.payments.isNotEmpty)
                SettingsGroup(
                  header: l.payment.toUpperCase(),
                  indentDividers: 16,
                  children: [
                    for (final p in a.payments)
                      SettingRow(
                        title: switch (p.kind) {
                          'DEPOSIT' => l.deposit,
                          'REFUND' => l.refund,
                          _ => l.payment,
                        },
                        subtitle: DateFormat('d MMM, HH:mm', locale).format(toBusinessLocal(p.paidAt)),
                        value: '${p.kind == 'REFUND' ? '−' : ''}${formatMoney(p.amountMinor, currency, locale)}',
                      ),
                  ],
                ),
              SettingsGroup(
                indentDividers: 16,
                children: [
                  if (a.status != 'CANCELLED')
                    SettingRow(title: l.recordPayment, icon: Icons.payments_rounded, iconColor: c.green, onTap: _busy ? null : () => _pay(a, currency)),
                  if (canAct)
                    SettingRow(
                      title: l.reschedule,
                      icon: Icons.edit_calendar_rounded,
                      iconColor: c.cyan,
                      onTap: _busy ? null : () => context.push('/appointment/${a.id}/edit'),
                    ),
                  if (a.status == 'BOOKED')
                    SettingRow(title: l.confirmAppointment, icon: Icons.check_rounded, iconColor: c.cyan, onTap: _busy ? null : () => _status('CONFIRMED')),
                  if (canAct)
                    SettingRow(title: l.markCompleted, icon: Icons.task_alt_rounded, iconColor: c.green, onTap: _busy ? null : () => _status('COMPLETED')),
                  if (canAct)
                    SettingRow(
                      title: l.markNoShow,
                      icon: Icons.person_off_rounded,
                      iconColor: c.pink,
                      onTap: _busy ? null : () => _status('NO_SHOW', confirm: true, title: l.markNoShow),
                    ),
                  if (canAct)
                    SettingRow(
                      title: l.cancelAppointment,
                      destructive: true,
                      icon: Icons.close_rounded,
                      iconColor: c.weekend,
                      onTap: _busy ? null : () => _status('CANCELLED', confirm: true, title: l.cancelAppointment),
                    ),
                  if (a.status == 'COMPLETED' || a.status == 'NO_SHOW')
                    SettingRow(title: l.statusBOOKED, icon: Icons.undo_rounded, iconColor: c.textSecondary, onTap: _busy ? null : () => _status('BOOKED')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.appointment, required this.currency});
  final Appointment appointment;
  final String currency;
  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  String _kind = 'PAYMENT';
  String _method = 'CASH';
  late final _amount = TextEditingController(text: (widget.appointment.balanceMinor / 100).toStringAsFixed(2));
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.recordPayment, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SegmentedControl<String>(
            expand: true,
            segments: {'DEPOSIT': l.deposit, 'PAYMENT': l.payment, 'REFUND': l.refund},
            value: _kind,
            onChanged: (v) => setState(() => _kind = v),
          ),
          const SizedBox(height: 12),
          SegmentedControl<String>(
            expand: true,
            segments: {'CASH': l.cash, 'CARD': l.card, 'TRANSFER': l.transfer},
            value: _method,
            onChanged: (v) => setState(() => _method = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '${l.amount}, ${widget.currency}'),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: l.save,
            loading: _busy,
            onPressed: () async {
              final v = double.tryParse(_amount.text.replaceAll(',', '.'));
              if (v == null || v <= 0) return showError(context, l.required);
              setState(() => _busy = true);
              try {
                await ref
                    .read(repositoryProvider)
                    .recordPayment(ref.read(sessionProvider).value!.businessId, widget.appointment.id, _kind, _method, (v * 100).round());
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) showError(context, e);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      ),
    );
  }
}
