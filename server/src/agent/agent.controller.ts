import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { CurrentUser, type RequestUser } from '../common/current-user.decorator';
import { AgentTasksService } from './agent-tasks.service';
import { CreateAgentTaskDto } from './dto/create-agent-task.dto';

@Controller('agent')
@UseGuards(AuthGuard('jwt'))
export class AgentController {
  constructor(private readonly tasks: AgentTasksService) {}

  @Post('tasks')
  @HttpCode(HttpStatus.CREATED)
  async create(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateAgentTaskDto,
  ) {
    const task = await this.tasks.createAndEnqueue(user.id, dto.message);
    return {
      id: task.id,
      status: task.status,
      createdAt: task.createdAt,
    };
  }

  @Get('tasks/:id')
  async getTask(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    const task = await this.tasks.requireOwned(id, user.id);
    return {
      id: task.id,
      status: task.status,
      input: task.input,
      resultSummary: task.resultSummary,
      errorMessage: task.errorMessage,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }
}
