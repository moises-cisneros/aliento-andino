import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';

import { AnalyticsAdminService, InstrumentMetrics } from './analytics-admin.service';
import { environment } from '../../../environments/environment';

describe('AnalyticsAdminService', () => {
  let service: AnalyticsAdminService;
  let httpMock: HttpTestingController;
  const base = `${environment.apiBaseUrl}/v1/analytics`;

  const rows: InstrumentMetrics[] = [
    {
      instrument: 'quena',
      sessions: 2,
      avg_score: 90,
      avg_note_precision: 0.7,
      avg_tempo_accuracy: 0.9,
      completion_rate: 0.5,
    },
  ];

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(AnalyticsAdminService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('getInstrumentMetrics con "all" no agrega el query param instrument', () => {
    service.getInstrumentMetrics('all').subscribe((res) => expect(res).toEqual(rows));

    const req = httpMock.expectOne(`${base}/instruments`);
    expect(req.request.method).toBe('GET');
    expect(req.request.params.has('instrument')).toBe(false);
    req.flush(rows);
  });

  it('getInstrumentMetrics con un instrumento agrega el query param', () => {
    service.getInstrumentMetrics('quena').subscribe();

    const req = httpMock.expectOne(
      (r) => r.url === `${base}/instruments` && r.params.get('instrument') === 'quena',
    );
    req.flush(rows);
  });

  it('getLessonDropoff consulta el endpoint de deserción', () => {
    service.getLessonDropoff('zampona').subscribe();

    const req = httpMock.expectOne(
      (r) => r.url === `${base}/lessons/dropoff` && r.params.get('instrument') === 'zampona',
    );
    req.flush([]);
  });

  it('exportMetricsCsv genera un Blob CSV con encabezado y filas', async () => {
    let blob: Blob | undefined;
    service.exportMetricsCsv('quena').subscribe((b) => (blob = b));
    httpMock.expectOne((r) => r.url === `${base}/instruments`).flush(rows);

    expect(blob).toBeInstanceOf(Blob);
    const text = await (blob as Blob).text();
    expect(text).toContain('instrument,sessions,avg_score,avg_note_precision');
    expect(text).toContain('quena,2,90,0.7,0.9,0.5');
  });
});
