import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateAgentTaskDto {
  @IsString()
  @MinLength(1)
  @MaxLength(32000)
  message!: string;
}
