import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { AgentTaskStatus } from './agent-task-status.enum';

@Entity('agent_tasks')
export class AgentTask {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ type: 'varchar', length: 32 })
  status!: AgentTaskStatus;

  @Column({ name: 'bull_job_id', type: 'varchar', length: 128, nullable: true })
  bullJobId!: string | null;

  @Column({ type: 'jsonb' })
  input!: { message: string };

  @Column({ name: 'result_summary', type: 'text', nullable: true })
  resultSummary!: string | null;

  @Column({ name: 'error_message', type: 'text', nullable: true })
  errorMessage!: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
