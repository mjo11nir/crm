import { BadRequestException, Body, Controller, Delete, Get, Header, HttpCode, NotFoundException, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsIn, IsInt, IsISO8601, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
import { Roles, Tenant, TenantContext } from '../common/auth';
import { toCsv } from '../common/csv';
import { PrismaService } from '../common/prisma.service';
import { RequiresFeature } from '../subscriptions/entitlement.guard';
import { FinanceService } from './finance.service';

class PaymentDto {
  @ApiProperty({ enum: ['DEPOSIT', 'PAYMENT', 'REFUND'] }) @IsIn(['DEPOSIT', 'PAYMENT', 'REFUND']) kind: 'DEPOSIT' | 'PAYMENT' | 'REFUND';
  @ApiProperty({ enum: ['CASH', 'CARD', 'TRANSFER'], description: 'ONLINE payments only via a verified provider webhook (not configured)' })
  @IsIn(['CASH', 'CARD', 'TRANSFER']) method: 'CASH' | 'CARD' | 'TRANSFER';
  @ApiProperty() @IsInt() @Min(1) @Max(100_000_000) amountMinor: number;
}

class ExpenseDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(60) category: string;
  @ApiProperty() @IsInt() @Min(1) @Max(100_000_000) amountMinor: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) note?: string;
  @ApiProperty() @IsISO8601({ strict: true }) spentAt: string;
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;

@ApiTags('finance')
@ApiBearerAuth()
@RequiresFeature('finance')
@Controller('businesses/:businessId')
export class FinanceController {
  constructor(private readonly finance: FinanceService, private readonly prisma: PrismaService) {}

  @Post('appointments/:id/payments')
  pay(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PaymentDto) {
    return this.finance.recordPayment(t.businessId, id, dto);
  }

  @Get('finance/report') @Roles('OWNER', 'ADMIN')
  report(@Tenant() t: TenantContext, @Query('from') from: string, @Query('to') to: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    return this.finance.report(t.businessId, from, to);
  }

  @Get('finance/report.csv') @Roles('OWNER', 'ADMIN') @RequiresFeature('excel_export')
  @Header('Content-Type', 'text/csv; charset=utf-8') @Header('Content-Disposition', 'attachment; filename="report.csv"')
  async reportCsv(@Tenant() t: TenantContext, @Query('from') from: string, @Query('to') to: string) {
    if (!DATE.test(from ?? '') || !DATE.test(to ?? '')) throw new BadRequestException('from/to must be YYYY-MM-DD');
    const r = await this.finance.report(t.businessId, from, to);
    return toCsv(['date', 'earnedMinor', 'currency'], r.daily.map((d) => [d.date, d.amountMinor, r.currency]));
  }

  @Get('expenses') @Roles('OWNER', 'ADMIN')
  expenses(@Tenant() t: TenantContext) {
    return this.prisma.expense.findMany({ where: { businessId: t.businessId }, orderBy: { spentAt: 'desc' }, take: 500 });
  }

  @Post('expenses') @Roles('OWNER', 'ADMIN')
  async addExpense(@Tenant() t: TenantContext, @Body() dto: ExpenseDto) {
    const b = await this.prisma.business.findUniqueOrThrow({ where: { id: t.businessId } });
    return this.prisma.expense.create({ data: { ...dto, spentAt: new Date(dto.spentAt), currency: b.currency, businessId: t.businessId } });
  }

  @Delete('expenses/:id') @Roles('OWNER', 'ADMIN') @HttpCode(204)
  async deleteExpense(@Tenant() t: TenantContext, @Param('id', ParseUUIDPipe) id: string) {
    const r = await this.prisma.expense.deleteMany({ where: { id, businessId: t.businessId } });
    if (!r.count) throw new NotFoundException();
  }
}
