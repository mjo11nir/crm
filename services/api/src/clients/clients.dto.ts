import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsBoolean, IsEmail, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

export class ClientDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(160) fullName: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(32) phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
  @ApiPropertyOptional() @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) birthday?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsArray() @ArrayMaxSize(20) @IsString({ each: true }) @MaxLength(40, { each: true }) tags?: string[];
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) discountPercent?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() marketingConsent?: boolean;
}

export class UpdateClientDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(160) fullName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(32) phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
  @ApiPropertyOptional() @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) birthday?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(4000) notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsArray() @ArrayMaxSize(20) @IsString({ each: true }) tags?: string[];
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) discountPercent?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() marketingConsent?: boolean;
}

export class MergeClientsDto {
  @ApiProperty() @IsUUID() sourceId: string;
  @ApiProperty() @IsUUID() targetId: string;
}

export class ImportClientsDto {
  @ApiProperty({ description: 'CSV text with header: fullName,phone,email,birthday,notes' }) @IsString() @MaxLength(5_000_000) csv: string;
}
