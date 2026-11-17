import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../../environments/environment';

/** Métricas pedagógicas agregadas de un instrumento (SUB-21-A). */
export interface InstrumentMetrics {
  instrument: string;
  sessions: number;
  avg_score: number;
  avg_note_precision: number;
  avg_tempo_accuracy: number;
  completion_rate: number;
}

/** Tasa de deserción por lección. */
export interface LessonDropoff {
  lesson_id: string;
  title: string;
  attempts: number;
  completed: number;
  dropoff_rate: number;
}

/**
 * [SUB-21-B] Servicio de analítica pedagógica por instrumento para el panel
 * docente. Consume los endpoints de SUB-21-A (`/api/v1/analytics/*`) y genera
 * el CSV de exportación en el cliente a partir de las métricas obtenidas.
 */
@Injectable({ providedIn: 'root' })
export class AnalyticsAdminService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiBaseUrl}/v1/analytics`;

  getInstrumentMetrics(instrument: string): Observable<InstrumentMetrics[]> {
    return this.http.get<InstrumentMetrics[]>(`${this.url}/instruments`, {
      params: this.instrumentParams(instrument),
    });
  }

  getLessonDropoff(instrument: string): Observable<LessonDropoff[]> {
    return this.http.get<LessonDropoff[]>(`${this.url}/lessons/dropoff`, {
      params: this.instrumentParams(instrument),
    });
  }

  /** Exporta las métricas por instrumento como CSV (generado en el cliente). */
  exportMetricsCsv(instrument: string): Observable<Blob> {
    return this.getInstrumentMetrics(instrument).pipe(map((rows) => this.toCsvBlob(rows)));
  }

  private instrumentParams(instrument: string): HttpParams {
    let params = new HttpParams();
    if (instrument && instrument !== 'all') {
      params = params.set('instrument', instrument);
    }
    return params;
  }

  private toCsvBlob(rows: InstrumentMetrics[]): Blob {
    const header = [
      'instrument',
      'sessions',
      'avg_score',
      'avg_note_precision',
      'avg_tempo_accuracy',
      'completion_rate',
    ];
    const lines = [header.join(',')];
    for (const r of rows) {
      lines.push(
        [
          r.instrument,
          r.sessions,
          r.avg_score,
          r.avg_note_precision,
          r.avg_tempo_accuracy,
          r.completion_rate,
        ].join(','),
      );
    }
    return new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
  }
}
