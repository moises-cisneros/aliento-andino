/// Modelo de lección musical andina (Quena, Zampoña, Tarka).
export type AndeanInstrument = 'quena' | 'zampona' | 'tarka';
export type LessonDifficulty = 'principiante' | 'intermedio' | 'avanzado';

export interface Lesson {
  id: string;
  category_id: string;
  title: string;
  description: string;
  instrument: AndeanInstrument;
  difficulty: LessonDifficulty;
  tempo_bpm: number;
  time_signature: string;
  key_signature: string;
  genre?: string | null;
  artist?: string | null;
  thumbnail_url: string | null;
  audio_preview_url: string | null;
  duration_seconds: number | null;
  order: number;
  is_active: boolean;
  is_premium: boolean;
  total_plays: number;
  average_score: number;
  created_by: string | null;
  created_at: string;
  updated_at: string | null;
  category_name: string | null;
  notes_count: number;
  notes?: NoteSequence[];
}

export interface LessonCreate {
  category_id: string;
  title: string;
  description?: string;
  instrument?: AndeanInstrument;
  difficulty: LessonDifficulty | string;
  tempo_bpm: number;
  time_signature?: string;
  key_signature?: string;
  genre?: string | null;
  artist?: string | null;
  order?: number;
  is_premium?: boolean;
  notes?: NoteSequenceCreate[];
}

export interface LessonUpdate {
  title?: string;
  description?: string;
  instrument?: AndeanInstrument;
  difficulty?: LessonDifficulty | string;
  tempo_bpm?: number;
  time_signature?: string;
  key_signature?: string;
  genre?: string | null;
  artist?: string | null;
  category_id?: string;
  order?: number;
  is_active?: boolean;
  is_premium?: boolean;
  notes?: NoteSequenceCreate[];
}

/// Modelo de nota/secuencia musical andina.
export interface NoteSequence {
  id: string;
  lesson_id: string;
  position: number;
  note: string;
  duration: number;
  is_rest: boolean;
  is_chord: boolean;
  chord_group: number | null;
  velocity: number;
  finger: number | null;
  hand: string | null;
  has_breath_mark?: boolean;
  fingering?: string | null;
  created_at: string;
}

export interface NoteSequenceCreate {
  position: number;
  note: string;
  duration: number;
  is_rest?: boolean;
  is_chord?: boolean;
  chord_group?: number | null;
  velocity?: number;
  finger?: number | null;
  hand?: string | null;
  has_breath_mark?: boolean;
  fingering?: string | null;
}

/// Respuesta paginada.
export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  size: number;
  pages: number;
}

/// Estadísticas de administración.
export interface AdminStatsOverview {
  total_lessons: number;
  total_categories: number;
  total_practice_sessions: number;
  total_users_active: number;
  most_played_lesson: string | null;
  highest_rated_lesson: string | null;
}
