# Reference audit

Five screenshots were supplied (the brief mentions six; the "main dashboard" and "profile settings" items map to images 2 and 4). Files: `docs/reference/1.jpg … 5.jpg`.
Golden tests reproducing each screen with fixed data: `apps/mobile/test/goldens/`.

| Ref | Screen | Observed element | Implementation | Status |
|---|---|---|---|---|
| 1 | Расписание | Segmented День / Неделя / Лента | `SegmentedControl`, `ScheduleScreen` 3 views | ✅ |
| 1 | | Purple month title with collapse chevron | tap toggles month ↔ week; swipe changes month | ✅ |
| 1 | | Month grid, teal selected circle, red non-working days, grey/green dots | `MonthCalendar`, red = days without schedule; grey = staff bookings, green = online | ✅ |
| 1 | | "Сегодня Чт, 12 нояб." + "09:00 - 19:00 >" | working hours from API; tap → schedule settings | ✅ |
| 1 | | Bordered appointment card: times, client, service, price, avatar + pink bell | `AppointmentCard` (bell = client has phone → reminders) | ✅ |
| 1 | | "18:15 создать запись или перерыв / свободно: 45 мин" | `FreeGapCard` from server free gaps; tap → create at that time | ✅ (breaks as separate entity ❌) |
| 1 | | Bottom bar: search, "Выручка за день", "Сегодня" | `_BottomBar`; search opens Лента with query | ✅ |
| 2 | Главная | Pastel gradient, avatar, name, black tier badge, bell | `HomeScreen`, badge from subscription | ✅ |
| 2 | | Week strip with selected black circle, red weekend | `CalendarWeekStrip` | ✅ |
| 2 | | Day appointments + "Выручка: €135" | dashboard endpoint | ✅ |
| 2 | | "Создать запись" card | opens form | ✅ |
| 2 | | Clients card (total, +N в ноябре) | live counts | ✅ |
| 2 | | Finance card with green/purple bar | completed vs planned revenue | ✅ |
| 2 | | Quick actions (create, free slots, notifications, help) | all wired | ✅ (help → support chat) |
| 3,5 | Свободные окна | Закрыть, Поделиться / Найти и записать | both tabs functional | ✅ |
| 3,5 | | Location, Период, Вид, Цветовая тема rows | all functional | ✅ |
| 3,5 | | Purple share card with contact & times by day | `AvailabilityCard`, real availability (compact mode) | ✅ |
| 3,5 | | "Отправить" | PNG render + native share sheet / text | ✅ |
| 4 | Профиль / Настройки | Grouped rows with coloured icon tiles | `SettingsGroup`/`SettingRow`; every row opens a screen | ✅ / some screens show "not connected" (see limitations) |
| 4 | | Bottom nav Главная/Расписание/Чаты/Другое | `AppShell`, state preserved per tab | ✅ |
