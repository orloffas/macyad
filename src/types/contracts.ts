export type PairSeverity = 'Healthy' | 'Info' | 'Warning' | 'Alarm';

export interface SyncPairSummaryDto {
  id: number;
  name: string;
  remote_path: string;
  local_relative_path: string;
  severity: PairSeverity;
  schedule_minutes: number;
}

export interface AppOverview {
  ui_language: string;
  has_rclone: boolean;
  next_push_in_minutes: number | null;
  pairs: SyncPairSummaryDto[];
}
