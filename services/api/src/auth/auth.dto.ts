import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty() @IsEmail() @MaxLength(254) email: string;
  @ApiProperty() @IsString() @MinLength(8) @MaxLength(128) password: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(120) fullName: string;
  @ApiProperty() @IsString() @MinLength(1) @MaxLength(120) businessName: string;
  @ApiProperty({ required: false }) @IsOptional() @IsString() @MaxLength(32) phone?: string;
  @ApiProperty({ required: false, example: 'Europe/Istanbul' }) @IsOptional() @IsString() timezone?: string;
  @ApiProperty({ required: false, example: 'EUR' }) @IsOptional() @Matches(/^[A-Z]{3}$/) currency?: string;
}

export class LoginDto {
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty() @IsString() @MaxLength(128) password: string;
}

export class RefreshDto {
  @ApiProperty() @IsString() @MinLength(20) refreshToken: string;
}

export class DeleteAccountDto {
  @ApiProperty() @IsString() password: string;
}
