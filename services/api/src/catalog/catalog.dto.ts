import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';

export class ServiceDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(160) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() categoryId?: string;
  @ApiProperty() @IsInt() @Min(5) @Max(1440) durationMinutes: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(240) bufferMinutes?: number;
  @ApiProperty({ description: 'minor units' }) @IsInt() @Min(0) @Max(100_000_000) priceMinor: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) depositMinor?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() onlineBookable?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isActive?: boolean;
}

export class UpdateServiceDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MinLength(1) @MaxLength(160) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() categoryId?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(5) @Max(1440) durationMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(240) bufferMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100_000_000) priceMinor?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) depositMinor?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() onlineBookable?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isActive?: boolean;
}

export class CategoryDto {
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(80) name: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() sortOrder?: number;
}
