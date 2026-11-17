import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';

import { FingeringAdminService } from './fingering-admin.service';
import { Fingering, FingeringCreate } from '../models/fingering.model';
import { environment } from '../../../environments/environment';

describe('FingeringAdminService', () => {
  let service: FingeringAdminService;
  let httpMock: HttpTestingController;

  const mockFingering: Fingering = {
    id: 'f-uuid-1234',
    instrument: 'quena',
    note: 'G',
    octave: 4,
    holes_covered: [1, 1, 1, 1, 1, 1, 1],
    is_alternate: false,
    description: 'Sol4 fundamental en Quena',
    created_at: new Date().toISOString(),
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [FingeringAdminService, provideHttpClient(), provideHttpClientTesting()],
    });

    service = TestBed.inject(FingeringAdminService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('debe crearse correctamente el servicio', () => {
    expect(service).toBeTruthy();
  });

  it('debe obtener digitaciones filtrando por instrumento', () => {
    let result: Fingering[] = [];

    service.getFingerings('quena').subscribe((data) => {
      result = data;
    });

    const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/fingerings?instrument=quena`);
    expect(req.request.method).toBe('GET');
    req.flush([mockFingering]);

    expect(result.length).toBe(1);
    expect(result[0].instrument).toBe('quena');
    expect(service.fingerings().length).toBe(1);
  });

  it('debe crear una digitación exitosamente vía POST /api/v1/fingerings', () => {
    const newFingeringData: FingeringCreate = {
      instrument: 'quena',
      note: 'A',
      octave: 4,
      holes_covered: [1, 1, 1, 1, 1, 0, 0],
      is_alternate: false,
      description: 'La4 en Quena',
    };

    let createdResult: Fingering | undefined;

    service.createFingering(newFingeringData).subscribe((fingering) => {
      createdResult = fingering;
    });

    const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/fingerings`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(newFingeringData);

    const mockResponse: Fingering = {
      ...newFingeringData,
      id: 'f-uuid-5678',
      created_at: new Date().toISOString(),
    };
    req.flush(mockResponse);

    expect(createdResult).toBeDefined();
    expect(createdResult?.note).toBe('A');
    expect(service.fingerings()[0].id).toBe('f-uuid-5678');
  });

  it('debe propagar error 409 cuando se intenta registrar una digitación principal duplicada', () => {
    const duplicateData: FingeringCreate = {
      instrument: 'quena',
      note: 'G',
      octave: 4,
      holes_covered: [1, 1, 1, 1, 1, 1, 1],
      is_alternate: false,
    };

    let errorDetail: string | undefined;

    service.createFingering(duplicateData).subscribe({
      next: () => {
        throw new Error('Debió fallar con 409');
      },
      error: (err) => {
        errorDetail = err.error?.detail;
      },
    });

    const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/fingerings`);
    req.flush(
      { detail: 'Digitación principal ya registrada para esta nota' },
      { status: 409, statusText: 'Conflict' },
    );

    expect(errorDetail).toBe('Digitación principal ya registrada para esta nota');
    expect(service.error()).toBe('Digitación principal ya registrada para esta nota');
  });

  it('debe eliminar una digitación vía DELETE /api/v1/fingerings/:id', () => {
    service.fingerings.set([mockFingering]);

    let deleted = false;
    service.deleteFingering(mockFingering.id).subscribe(() => {
      deleted = true;
    });

    const req = httpMock.expectOne(`${environment.apiBaseUrl}/v1/fingerings/${mockFingering.id}`);
    expect(req.request.method).toBe('DELETE');
    req.flush(null);

    expect(deleted).toBe(true);
    expect(service.fingerings().length).toBe(0);
  });
});
