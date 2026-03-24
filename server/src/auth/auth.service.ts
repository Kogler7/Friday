import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { QueryFailedError } from 'typeorm';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<{ token: string; user: { id: string; email: string } }> {
    const hash = await bcrypt.hash(dto.password, 12);
    try {
      const user = await this.users.create(dto.email, hash);
      return this.issue(user);
    } catch (e) {
      if (e instanceof QueryFailedError) {
        const driverError = (e as QueryFailedError & { driverError?: { code?: string } })
          .driverError;
        if (driverError?.code === '23505') {
          throw new ConflictException('该邮箱已注册');
        }
      }
      throw e;
    }
  }

  async login(dto: LoginDto): Promise<{ token: string; user: { id: string; email: string } }> {
    const user = await this.users.findByEmail(dto.email);
    if (!user) {
      throw new UnauthorizedException('邮箱或密码错误');
    }
    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('邮箱或密码错误');
    }
    return this.issue(user);
  }

  private issue(user: { id: string; email: string }): {
    token: string;
    user: { id: string; email: string };
  } {
    const payload = { sub: user.id, email: user.email };
    return {
      token: this.jwt.sign(payload),
      user: { id: user.id, email: user.email },
    };
  }
}
