/**
 * Development seed — fictional demo data only. Never run against production.
 * Login: demo@beauty-crm.test / Demo12345!
 */
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { DateTime } from 'luxon';

const prisma = new PrismaClient();
const TZ = 'Europe/Istanbul';

async function main() {
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to seed production');
  await prisma.user.deleteMany({ where: { email: 'demo@beauty-crm.test' } });
  // appointments first: appointment_services -> services is ON DELETE RESTRICT (history protection)
  await prisma.appointment.deleteMany({ where: { business: { slug: 'lavanda-studio' } } });
  await prisma.business.deleteMany({ where: { slug: 'lavanda-studio' } });

  const user = await prisma.user.create({ data: { email: 'demo@beauty-crm.test', passwordHash: await bcrypt.hash('Demo12345!', 10), fullName: 'Анна Смирнова', phone: '+90 500 000 00 00' } });
  const business = await prisma.business.create({ data: { name: 'Лаванда Studio', slug: 'lavanda-studio', timezone: TZ, currency: 'EUR', phone: '+90 500 000 00 00', description: 'Маникюр и педикюр у моря' } });
  const member = await prisma.businessMember.create({ data: { businessId: business.id, userId: user.id, role: 'OWNER' } });
  const employee = await prisma.employee.create({ data: { businessId: business.id, memberId: member.id, displayName: user.fullName } });
  const location = await prisma.workLocation.create({ data: { businessId: business.id, name: 'Iskele', address: 'Long beach, Iskele' } });
  await prisma.workSchedule.createMany({ data: [1, 2, 3, 4, 5].map((weekday) => ({ businessId: business.id, employeeId: employee.id, locationId: location.id, weekday, startMinute: 540, endMinute: 1140 })) });
  await prisma.subscription.create({ data: { businessId: business.id, tier: 'VIP', status: 'ACTIVE', store: 'MANUAL', expiresAt: DateTime.now().plus({ months: 1 }).toJSDate() } });
  const cat = await prisma.serviceCategory.create({ data: { businessId: business.id, name: 'Ногтевой сервис' } });
  const services = await Promise.all([
    prisma.service.create({ data: { businessId: business.id, categoryId: cat.id, name: 'Маникюр с однотонным покрытием', durationMinutes: 120, priceMinor: 4500 } }),
    prisma.service.create({ data: { businessId: business.id, categoryId: cat.id, name: 'Педикюр с покрытием', durationMinutes: 90, priceMinor: 5000 } }),
    prisma.service.create({ data: { businessId: business.id, categoryId: cat.id, name: 'Снятие покрытия', durationMinutes: 30, priceMinor: 1000 } }),
  ]);
  const names = ['Тамара Крайс', 'Кристина Суворова', 'Елена Герасимова', 'Мама Халиде', 'Наталья Орлова', 'Ольга Белова', 'Ирина Котова', 'Мария Лебедева', 'Светлана Попова', 'Дарья Морозова', 'Юлия Волкова', 'Алина Соколова'];
  const clients = await Promise.all(names.map((fullName, i) => prisma.client.create({ data: { businessId: business.id, fullName, phone: `+90 533 000 ${String(10 + i).padStart(2, '0')} ${String(20 + i)}`, phoneNormalized: `90533000${String(10 + i).padStart(2, '0')}${20 + i}`, createdAt: DateTime.now().minus({ months: 2 }).toJSDate() } })));

  const today = DateTime.now().setZone(TZ).startOf('day');
  const monthStart = today.startOf('month');
  let k = 0;
  for (let d = monthStart.minus({ days: 3 }); d < monthStart.plus({ months: 1, days: 7 }); d = d.plus({ days: 1 })) {
    if (d.weekday > 5) continue;
    const hours = (d.day * 7) % 3 === 0 ? [9, 13, 15] : (d.day % 2 === 0 ? [9, 11] : [13]);
    for (const h of hours) {
      const svc = services[0];
      const startsAt = d.set({ hour: h }).toJSDate();
      const past = d < today;
      await prisma.appointment.create({
        data: {
          businessId: business.id, clientId: clients[k++ % clients.length].id, employeeId: employee.id, locationId: location.id,
          startsAt, endsAt: new Date(+startsAt + svc.durationMinutes * 60_000), status: past ? 'COMPLETED' : 'BOOKED', source: k % 4 === 0 ? 'ONLINE' : 'STAFF',
          priceMinor: svc.priceMinor,
          services: { create: { serviceId: svc.id, nameSnapshot: svc.name, durationMinutes: svc.durationMinutes, priceMinor: svc.priceMinor } },
          history: { create: { toStatus: 'BOOKED' } },
        },
      });
    }
  }
  const conv = await prisma.conversation.create({ data: { businessId: business.id, title: 'Поддержка', kind: 'SUPPORT' } });
  await prisma.message.create({ data: { conversationId: conv.id, body: 'Добро пожаловать! Напишите нам, если нужна помощь.' } });
  console.log(`Seeded business ${business.slug}. Login demo@beauty-crm.test / Demo12345!`);
}

main().finally(() => prisma.$disconnect());
