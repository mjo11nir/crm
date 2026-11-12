import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsHexColor, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';

export class UpdateBusinessDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(32) phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() timezone?: string;
  @ApiPropertyOptional() @IsOptional() @Matches(/^[A-Z]{3}$/) currency?: string;
  @ApiPropertyOptional() @IsOptional() @IsHexColor() themeColor?: string;
  @ApiPropertyOptional() @IsOptional() @Matches(/^[a-z0-9](?:[a-z0-9-]{1,48}[a-z0-9])$/) slug?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() onlineBookingEnabled?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(43200) minNoticeMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(365) maxHorizonDays?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(5) @Max(240) slotStepMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(43200) cancellationDeadlineMin?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() requireApproval?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() waitlistEnabled?: boolean;
}

export class LocationDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(120) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(300) address?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isActive?: boolean;
}

export class ScheduleDayDto {
  @ApiProperty() @IsInt() @Min(1) @Max(7) weekday: number;
  @ApiProperty() @IsInt() @Min(0) @Max(1439) startMinute: number;
  @ApiProperty() @IsInt() @Min(1) @Max(2880) endMinute: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(2880) breakStartMinute?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(2880) breakEndMinute?: number;
  @ApiProperty() @IsUUID() locationId: string;
}

export class ReplaceScheduleDto {
  @ApiProperty({ type: [ScheduleDayDto] }) @IsArray() @ArrayMaxSize(28) @ValidateNested({ each: true }) @Type(() => ScheduleDayDto) days: ScheduleDayDto[];
}

export class ScheduleExceptionDto {
  @ApiProperty() @Matches(/^\d{4}-\d{2}-\d{2}$/) date: string;
  @ApiProperty() @IsBoolean() isClosed: boolean;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(1439) startMinute?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(2880) endMinute?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) note?: string;
}
