import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { CurrentUser, type RequestUser } from '../common/current-user.decorator';

@Controller()
export class ProfileController {
  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  me(@CurrentUser() user: RequestUser): RequestUser {
    return user;
  }
}
