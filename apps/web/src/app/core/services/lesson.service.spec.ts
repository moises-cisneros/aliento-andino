import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';

import { LessonService } from './lesson.service';
import { environment } from '../../../environments/environment';

describe('LessonService.loadLessons', () => {
  let service: LessonService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(LessonService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('envía instrument al endpoint /admin/lessons junto con los demás filtros', () => {
    service.loadLessons({ page: 1, instrument: 'tarka', difficulty: 'intermedio' }).subscribe();
    const req = httpMock.expectOne((r) => r.url === `${environment.apiBaseUrl}/admin/lessons`);
    expect(req.request.params.get('instrument')).toBe('tarka');
    expect(req.request.params.get('difficulty')).toBe('intermedio');
    req.flush({ items: [], total: 0, page: 1, size: 10, pages: 0 });
  });

  it('omite instrument cuando no hay filtro', () => {
    service.loadLessons({ page: 1 }).subscribe();
    const req = httpMock.expectOne((r) => r.url === `${environment.apiBaseUrl}/admin/lessons`);
    expect(req.request.params.has('instrument')).toBe(false);
    req.flush({ items: [], total: 0, page: 1, size: 10, pages: 0 });
  });
});
