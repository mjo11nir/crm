import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes, randomUUID } from 'crypto';
import { config } from '../common/config';
import { isValidZone } from '../common/dates';
import { PrismaService } from '../common/prisma.service';
import { LoginDto, RegisterDto } from './auth.dto';

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

function slugify(name: string): string {
  const map: Record<string, string> = { а:'a',б:'b',в:'v',г:'g',д:'d',е:'e',ё:'e',ж:'zh',з:'z',и:'i',й:'y',к:'k',л:'l',м:'m',н:'n',о:'o',п:'p',р:'r',с:'s',т:'t',у:'u',ф:'f',х:'h',ц:'ts',ч:'ch',ш:'sh',щ:'sch',ы:'y',э:'e',ю:'yu',я:'ya' };
  const base = name.toLowerCase().split('').map((c) => map[c] ?? c).join('')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40);
  return base || 'studio';
}

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async register(dto: RegisterDto, userAgent?: string) {
    const email = dto.email.trim().toLowerCase();
    const timezone = dto.timezone ?? 'Europe/Istanbul';
    if (!isValidZone(timezone)) throw new BadRequestException('Invalid IANA timezone');
    if (await this.prisma.user.findUnique({ where: { email } })) throw new ConflictException('Email already registered');
    const passwordHash = await bcrypt.hash(dto.password, config.bcryptRounds);
    const slug = `${slugify(dto.businessName)}-${randomBytes(3).toString('hex')}`;

    const user = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({ data: { email, passwordHash, fullName: dto.fullName.trim(), phone: dto.phone } });
      const business = await tx.business.create({
        data: { name: dto.businessName.trim(), slug, timezone, currency: dto.currency ?? 'EUR', phone: dto.phone },
      });
      const member = await tx.businessMember.create({ data: { businessId: business.id, userId: user.id, role: 'OWNER' } });
      const employee = await tx.employee.create({ data: { businessId: business.id, memberId: member.id, displayName: user.fullName } });
      const location = await tx.workLocation.create({ data: { businessId: business.id, name: 'Основной адрес' } });
      // Default schedule Mon–Fri 09:00–19:00, editable in settings.
      await tx.workSchedule.createMany({
        data: [1, 2, 3, 4, 5].map((weekday) => ({
          businessId: business.id, employeeId: employee.id, locationId: location.id, weekday, startMinute: 540, endMinute: 1140,
        })),
      });
      await tx.subscription.create({
        data: { businessId: business.id, tier: 'TRIAL', status: 'ACTIVE', store: 'MANUAL', expiresAt: new Date(Date.now() + config.trialDays * 86_400_000) },
      });
      return user;
    });
    return this.issueTokens(user.id, randomUUID(), userAgent);
  }

  async login(dto: LoginDto, userAgent?: string) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email.trim().toLowerCase() } });
    // Compare even when user is missing to keep timing similar.
    const ok = await bcrypt.compare(dto.password, user?.passwordHash ?? '$2a$04$invalidinvalidinvalidinvalidinvalidinvalidinvalidinva');
    if (!user || !ok || user.deletedAt) throw new UnauthorizedException('Invalid email or password');
    return this.issueTokens(user.id, randomUUID(), userAgent);
  }

  /** Refresh-token rotation with reuse detection: replaying a rotated token revokes the whole family. */
  async refresh(refreshToken: string, userAgent?: string) {
    const row = await this.prisma.refreshToken.findUnique({ where: { tokenHash: sha256(refreshToken) } });
    if (!row) throw new UnauthorizedException('Invalid refresh token');
    if (row.revokedAt) {
      await this.prisma.refreshToken.updateMany({ where: { familyId: row.familyId, revokedAt: null }, data: { revokedAt: new Date() } });
      throw new UnauthorizedException('Refresh token reuse detected');
    }
    if (row.expiresAt < new Date()) throw new UnauthorizedException('Refresh token expired');
    const revoked = await this.prisma.refreshToken.updateMany({ where: { id: row.id, revokedAt: null }, data: { revokedAt: new Date() } });
    if (revoked.count !== 1) throw new UnauthorizedException('Refresh token already used');
    const tokens = await this.issueTokens(row.userId, row.familyId, userAgent);
    return tokens;
  }

  async logout(refreshToken: string) {
    await this.prisma.refreshToken.updateMany({ where: { tokenHash: sha256(refreshToken), revokedAt: null }, data: { revokedAt: new Date() } });
  }

  async logoutAll(userId: string) {
    await this.prisma.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: {
        id: true, email: true, fullName: true, phone: true, avatarUrl: true, locale: true,
        memberships: { select: { role: true, business: { select: { id: true, name: true, slug: true, timezone: true, currency: true } } } },
      },
    });
    return user;
  }

  /** Account deletion: owner-only businesses are deleted with all tenant data (cascade); personal data is erased. */
  async deleteAccount(userId: string, password: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, include: { memberships: true } });
    if (!(await bcrypt.compare(password, user.passwordHash))) throw new UnauthorizedException('Wrong password');
    await this.prisma.$transaction(async (tx) => {
      for (const m of user.memberships.filter((m) => m.role === 'OWNER')) {
        const owners = await tx.businessMember.count({ where: { businessId: m.businessId, role: 'OWNER' } });
        if (owners === 1) await tx.business.delete({ where: { id: m.businessId } });
      }
      await tx.user.delete({ where: { id: userId } });
    });
  }

  private async issueTokens(userId: string, familyId: string, userAgent?: string) {
    const accessToken = await this.jwt.signAsync({ sub: userId, typ: 'access' }, { expiresIn: config.accessTtlSeconds });
    const refreshToken = randomBytes(48).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId, familyId, tokenHash: sha256(refreshToken), userAgent: userAgent?.slice(0, 255),
        expiresAt: new Date(Date.now() + config.refreshTtlDays * 86_400_000),
      },
    });
    return { accessToken, refreshToken, expiresIn: config.accessTtlSeconds };
  }
}
