import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import {
  Lesson,
  LessonCreate,
  LessonUpdate,
  NoteSequence,
  NoteSequenceCreate,
  PaginatedResponse,
  AdminStatsOverview,
} from '../models/lesson.model';

/// Servicio para gestión CRUD de lecciones (admin).
@Injectable({ providedIn: 'root' })
export class LessonService {
  private readonly adminUrl = `${environment.apiBaseUrl}/admin/lessons`;
  private readonly statsUrl = `${environment.apiBaseUrl}/admin/stats`;
  private readonly http = inject(HttpClient);

  // Estado reactivo
  readonly lessons = signal<Lesson[]>([]);
  readonly totalLessons = signal(0);
  readonly currentLesson = signal<Lesson | null>(null);
  readonly currentNotes = signal<NoteSequence[]>([]);
  readonly isLoading = signal(false);
  readonly stats = signal<AdminStatsOverview | null>(null);

  /// Cargar lecciones con paginación y filtros (admin).
  loadLessons(params?: {
    page?: number;
    limit?: number;
    category_id?: string;
    difficulty?: string;
    search?: string;
  }): Observable<PaginatedResponse<Lesson>> {
    this.isLoading.set(true);
    let httpParams = new HttpParams();
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.limit) httpParams = httpParams.set('limit', params.limit);
    if (params?.category_id) httpParams = httpParams.set('category_id', params.category_id);
    if (params?.difficulty) httpParams = httpParams.set('difficulty', params.difficulty);
    if (params?.search) httpParams = httpParams.set('search', params.search);

    return this.http
      .get<PaginatedResponse<Lesson>>(this.adminUrl, { params: httpParams })
      .pipe(
        tap((res) => {
          this.lessons.set(res.items);
          this.totalLessons.set(res.total);
          this.isLoading.set(false);
        }),
      );
  }

  /// Obtener detalle de lección con notas.
  getLesson(id: string): Observable<Lesson> {
    return this.http.get<Lesson>(`${this.adminUrl}/${id}`).pipe(
      tap((lesson) => this.currentLesson.set(lesson)),
    );
  }

  /// Obtener secuencia de notas de una lección.
  getLessonNotes(lessonId: string): Observable<NoteSequence[]> {
    return this.http
      .get<NoteSequence[]>(`${environment.apiBaseUrl}/lessons/${lessonId}/sequence`)
      .pipe(tap((notes) => this.currentNotes.set(notes)));
  }

  /// Crear nueva lección.
  create(data: LessonCreate): Observable<Lesson> {
    return this.http.post<Lesson>(this.adminUrl, data);
  }

  /// Actualizar lección existente.
  update(id: string, data: LessonUpdate): Observable<Lesson> {
    return this.http.put<Lesson>(`${this.adminUrl}/${id}`, data);
  }

  /// Reemplazar notas de una lección.
  updateNotes(lessonId: string, notes: NoteSequenceCreate[]): Observable<NoteSequence[]> {
    return this.http
      .put<NoteSequence[]>(`${this.adminUrl}/${lessonId}/notes`, { notes })
      .pipe(tap((updated) => this.currentNotes.set(updated)));
  }

  /// Eliminar lección (soft delete).
  delete(id: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.adminUrl}/${id}`);
  }

  /// Cargar estadísticas generales del admin.
  loadStats(): Observable<AdminStatsOverview> {
    return this.http.get<AdminStatsOverview>(`${this.statsUrl}/overview`).pipe(
      tap((s) => this.stats.set(s)),
    );
  }
}
