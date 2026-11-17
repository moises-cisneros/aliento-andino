import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';

import { LessonAdminService } from './lesson-admin.service';
import { LessonCreate, LessonUpdate, Lesson } from '../models/lesson.model';
import { environment } from '../../../environments/environment';

describe('LessonAdminService', () => {
  let service: LessonAdminService;
  let httpMock: HttpTestingController;

  const mockLesson: Lesson = {
    id: 'lesson-uuid-1234',
    category_id: 'cat-uuid-5678',
    title: 'El Cóndor Pasa - Escala en Quena',
    description: 'Lección andina introductoria para práctica de digitaciones.',
    instrument: 'quena',
    difficulty: 'principiante',
    tempo_bpm: 85,
    time_signature: '4/4',
    key_signature: 'G',
    genre: 'Huayno',
    artist: 'Daniel Alomía Robles',
    thumbnail_url: null,
    audio_preview_url: null,
    duration_seconds: 120,
    order: 1,
    is_active: true,
    is_premium: false,
    total_plays: 0,
    average_score: 0,
    created_by: 'admin-uuid',
    created_at: new Date().toISOString(),
    updated_at: null,
    category_name: 'Melodías Andinas',
    notes_count: 3,
    notes: [
      {
        id: 'note-1',
        lesson_id: 'lesson-uuid-1234',
        position: 1,
        note: 'G4',
        duration: 1.0,
        is_rest: false,
        is_chord: false,
        chord_group: null,
        velocity: 80,
        finger: null,
        hand: null,
        has_breath_mark: false,
        created_at: new Date().toISOString(),
      },
    ],
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [LessonAdminService, provideHttpClient(), provideHttpClientTesting()],
    });

    service = TestBed.inject(LessonAdminService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('debe crearse correctamente el servicio', () => {
    expect(service).toBeTruthy();
  });

  describe('createLesson (POST /api/v1/lessons)', () => {
    it('debe enviar POST a /api/v1/lessons con los datos de LessonCreate y actualizar el estado', () => {
      const payload: LessonCreate = {
        title: 'El Cóndor Pasa - Escala en Quena',
        description: 'Lección andina introductoria.',
        instrument: 'quena',
        category_id: 'cat-uuid-5678',
        difficulty: 'principiante',
        tempo_bpm: 85,
        time_signature: '4/4',
        key_signature: 'G',
        notes: [
          {
            position: 1,
            note: 'G4',
            duration: 1.0,
            is_rest: false,
            has_breath_mark: false,
          },
          {
            position: 2,
            note: 'A4',
            duration: 1.0,
            is_rest: false,
            has_breath_mark: true,
          },
        ],
      };

      service.createLesson(payload).subscribe((res) => {
        expect(res).toEqual(mockLesson);
        expect(service.lessons().length).toBe(1);
        expect(service.totalLessons()).toBe(1);
        expect(service.isLoading()).toBe(false);
      });

      const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/lessons`);
      expect(req.request.method).toBe('POST');
      expect(req.request.body).toEqual(payload);

      req.flush(mockLesson);
    });

    it('debe manejar error 401/403 de privilegios administrativos', () => {
      const payload: LessonCreate = {
        title: 'Lección no autorizada',
        description: 'Intento sin credenciales admin.',
        instrument: 'tarka',
        category_id: 'cat-1',
        difficulty: 'avanzado',
        tempo_bpm: 120,
        notes: [{ position: 1, note: 'C5', duration: 1.0 }],
      };

      service.createLesson(payload).subscribe({
        next: () => fail('Se esperaba que falle con 403 Forbidden'),
        error: (error) => {
          expect(error.status).toBe(403);
          expect(service.isLoading()).toBe(false);
          expect(service.error()).toBeTruthy();
        },
      });

      const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/lessons`);
      expect(req.request.method).toBe('POST');
      req.flush(
        { detail: 'No tiene privilegios administrativos' },
        { status: 403, statusText: 'Forbidden' },
      );
    });
  });

  describe('updateLesson (PUT /api/v1/lessons/{id})', () => {
    it('debe enviar PUT a /api/v1/lessons/{id} y actualizar la lección en la lista reactiva', () => {
      // Poblar lección inicial en el signal
      service.lessons.set([mockLesson]);

      const updatePayload: LessonUpdate = {
        title: 'El Cóndor Pasa - Versión Revisada',
        tempo_bpm: 90,
      };

      const updatedMock: Lesson = {
        ...mockLesson,
        title: 'El Cóndor Pasa - Versión Revisada',
        tempo_bpm: 90,
      };

      service.updateLesson(mockLesson.id, updatePayload).subscribe((res) => {
        expect(res.title).toBe('El Cóndor Pasa - Versión Revisada');
        expect(res.tempo_bpm).toBe(90);
        expect(service.lessons()[0].title).toBe('El Cóndor Pasa - Versión Revisada');
      });

      const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/lessons/${mockLesson.id}`);
      expect(req.request.method).toBe('PUT');
      expect(req.request.body).toEqual(updatePayload);

      req.flush(updatedMock);
    });
  });

  describe('loadLessons', () => {
    it('debe consultar /admin/lessons con parámetros de paginación e instrumento', () => {
      service.loadLessons({ page: 1, limit: 10, instrument: 'zampona' }).subscribe((res) => {
        expect(res.items.length).toBe(1);
        expect(res.total).toBe(1);
      });

      const req = httpMock.expectOne(
        (r) =>
          r.url === `${environment.apiBaseUrl}/admin/lessons` &&
          r.params.get('instrument') === 'zampona' &&
          r.params.get('page') === '1' &&
          r.params.get('limit') === '10',
      );
      expect(req.request.method).toBe('GET');

      req.flush({
        items: [mockLesson],
        total: 1,
        page: 1,
        size: 10,
        pages: 1,
      });
    });
  });
});
