import { Body, Controller, Delete, Get, Headers, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthUser, CurrentUser, Public } from '../common/auth';
import { DeleteAccountDto, LoginDto, RefreshDto, RegisterDto } from './auth.dto';
import { AuthService } from './auth.service';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public() @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('register')
  register(@Body() dto: RegisterDto, @Headers('user-agent') ua?: string) {
    return this.auth.register(dto, ua);
  }

  @Public() @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('login') @HttpCode(200)
  login(@Body() dto: LoginDto, @Headers('user-agent') ua?: string) {
    return this.auth.login(dto, ua);
  }

  @Public()
  @Post('refresh') @HttpCode(200)
  refresh(@Body() dto: RefreshDto, @Headers('user-agent') ua?: string) {
    return this.auth.refresh(dto.refreshToken, ua);
  }

  @Public()
  @Post('logout') @HttpCode(204)
  async logout(@Body() dto: RefreshDto) {
    await this.auth.logout(dto.refreshToken);
  }

  @ApiBearerAuth()
  @Post('logout-all') @HttpCode(204)
  async logoutAll(@CurrentUser() u: AuthUser) {
    await this.auth.logoutAll(u.userId);
  }

  @ApiBearerAuth()
  @Get('me')
  me(@CurrentUser() u: AuthUser) {
    return this.auth.me(u.userId);
  }

  @ApiBearerAuth()
  @Delete('account') @HttpCode(204)
  async deleteAccount(@CurrentUser() u: AuthUser, @Body() dto: DeleteAccountDto) {
    await this.auth.deleteAccount(u.userId, dto.password);
  }
}
