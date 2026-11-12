import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from './prisma.service';

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}
  async log(businessId: string, userId: string | null, action: string, entity: string, entityId?: string, data?: Prisma.InputJsonValue) {
    await this.prisma.auditLog.create({ data: { businessId, userId, action, entity, entityId, data } });
  }
}
