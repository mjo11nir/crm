import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { MemberRole } from '@prisma/client';
import { PrismaService } from './prisma.service';

export interface AuthUser {
  userId: string;
}
export interface TenantContext {
  businessId: string;
  role: MemberRole;
  userId: string;
}

export const IS_PUBLIC = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC, true);
export const ROLES = 'roles';
/** Restrict an endpoint to the listed member roles (tenant routes only). */
export const Roles = (...roles: MemberRole[]) => SetMetadata(ROLES, roles);

export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthUser => {
  return ctx.switchToHttp().getRequest().user;
});
export const Tenant = createParamDecorator((_: unknown, ctx: ExecutionContext): TenantContext => {
  return ctx.switchToHttp().getRequest().tenant;
});

/**
 * Global guard:
 *  1. verifies the bearer access token (unless @Public)
 *  2. for any route containing :businessId, verifies membership and loads role
 *     -> this is the service-layer tenant isolation boundary
 *  3. enforces @Roles
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()]);
    if (isPublic) return true;
    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers['authorization'];
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException('Missing bearer token');
    let payload: { sub: string; typ?: string };
    try {
      payload = await this.jwt.verifyAsync(header.slice(7));
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
    if (payload.typ !== 'access') throw new UnauthorizedException('Invalid token type');
    req.user = { userId: payload.sub } satisfies AuthUser;

    const businessId: string | undefined = req.params?.businessId;
    if (businessId) {
      if (!/^[0-9a-f-]{36}$/i.test(businessId)) throw new ForbiddenException('No access to this business');
      const member = await this.prisma.businessMember.findUnique({
        where: { businessId_userId: { businessId, userId: payload.sub } },
      });
      if (!member) throw new ForbiddenException('No access to this business');
      req.tenant = { businessId, role: member.role, userId: payload.sub } satisfies TenantContext;
      const roles = this.reflector.getAllAndOverride<MemberRole[] | undefined>(ROLES, [ctx.getHandler(), ctx.getClass()]);
      if (roles && !roles.includes(member.role)) throw new ForbiddenException('Insufficient role');
    }
    return true;
  }
}
