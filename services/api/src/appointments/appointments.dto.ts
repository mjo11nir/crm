import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsBoolean, IsIn, IsInt, IsISO8601, IsOptional, IsString, IsUUID, Max, MaxLength, Min, ValidateIf, ValidateNested } from 'class-validator';

export class RecurrenceDto {
  @ApiProperty() @IsInt() @Min(1) @Max(12) everyWeeks: number;
  @ApiProperty() @IsInt() @Min(2) @Max(52) count: number;
}

export class CreateAppointmentDto {
  @ApiPropertyOptional() @IsOptional() @IsUUID() clientId?: string;
  @ApiProperty({ type: [String] }) @IsArray() @ArrayMinSize(1) @ArrayMaxSize(10) @IsUUID('all', { each: true }) serviceIds: string[];
  @ApiPropertyOptional() @IsOptional() @IsUUID() employeeId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() locationId?: string;
  @ApiProperty({ example: '2026-11-20T09:00:00.000Z' }) @IsISO8601({ strict: true }) startsAt: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(5) @Max(1440) durationMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) discountPercent?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() allowOutsideHours?: boolean;
  @ApiPropertyOptional() @IsOptional() @ValidateNested() @Type(() => RecurrenceDto) recurrence?: RecurrenceDto;
}

export class UpdateAppointmentDto {
  @ApiProperty({ description: 'optimistic concurrency version' }) @IsInt() @Min(1) version: number;
  @ApiPropertyOptional() @IsOptional() @IsISO8601({ strict: true }) startsAt?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(5) @Max(1440) durationMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsUUID() employeeId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() locationId?: string;
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @ValidateIf((_, v) => v !== null) @IsUUID() clientId?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsArray() @ArrayMinSize(1) @IsUUID('all', { each: true }) serviceIds?: string[];
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) discountPercent?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() allowOutsideHours?: boolean;
}

export class StatusDto {
  @ApiProperty({ enum: ['BOOKED', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'] })
  @IsIn(['BOOKED', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'])
  status: 'BOOKED' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED' | 'NO_SHOW';
}
