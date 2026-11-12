import { Body, Controller, Get, NotFoundException, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';
import { Tenant, TenantContext } from '../common/auth';
import { PrismaService } from '../common/prisma.service';

class ConversationDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(120) title: string;
  @ApiProperty({ enum: ['INTERNAL', 'SUPPORT'] }) @IsIn(['INTERNAL', 'SUPPORT']) kind: 'INTERNAL' | 'SUPPORT';
}
class MessageDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(4000) body: string;
}

/**
 * Internal team chat and support tickets. External WhatsApp / Instagram inboxes are NOT simulated:
 * they require authorised Meta Business API access (status: BLOCKED, see docs/known-limitations.md).
 */
@ApiTags('chats')
@ApiBearerAuth()
@Controller('businesses/:businessId/conversations')
export class ChatsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Tenant() t: TenantContext) {
    const convs = await this.prisma.conversation.findMany({
      where: { businessId: t.businessId },
      include: { messages: { orderBy: { createdAt: 'desc' }, take: 1 } },
      orderBy: { updatedAt: 'desc' },
    });
    const unread = await this.prisma.message.groupBy({
      by: ['conversationId'],
      where: { conversation: { businessId: t.businessId }, readAt: null, OR: [{ senderUserId: null }, { senderUserId: { not: t.userId } }] },
      _count: true,
    });
    return convs.map((c) => ({ id: c.id, title: c.title, kind: c.kind, updatedAt: c.updatedAt, lastMessage: c.messages[0] ?? null, unread: unread.find((u) => u.conversationId === c.id)?._count ?? 0 }));
  }

  @Post()
  create(@Tenant() t: TenantContext, @Body() dto: ConversationDto) {
    return this.prisma.conversation.create({ data: { ...dto, businessId: t.businessId } });
  }

  @Get(':id/messages')
  async messages(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    await this.own(t.businessId, id);
    await this.prisma.message.updateMany({ where: { conversationId: id, readAt: null, OR: [{ senderUserId: null }, { senderUserId: { not: t.userId } }] }, data: { readAt: new Date() } });
    return this.prisma.message.findMany({ where: { conversationId: id }, orderBy: { createdAt: 'asc' }, take: 500 });
  }

  @Post(':id/messages')
  async send(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: MessageDto) {
    await this.own(t.businessId, id);
    const [m] = await this.prisma.$transaction([
      this.prisma.message.create({ data: { conversationId: id, senderUserId: t.userId, body: dto.body } }),
      this.prisma.conversation.update({ where: { id }, data: { updatedAt: new Date() } }),
    ]);
    return m;
  }

  private async own(businessId: string, id: string) {
    const c = await this.prisma.conversation.findFirst({ where: { id, businessId } });
    if (!c) throw new NotFoundException('Conversation not found');
  }
}
