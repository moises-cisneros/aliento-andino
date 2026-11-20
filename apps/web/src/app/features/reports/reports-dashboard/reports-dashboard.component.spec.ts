import { TestBed } from '@angular/core/testing';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { Observable, of, throwError } from 'rxjs';

import { ReportsDashboardComponent } from './reports-dashboard.component';
import { AnalyticsService } from '../../../core/services/analytics.service';
import {
  AnalyticsAdminService,
  InstrumentMetrics,
} from '../../../core/services/analytics-admin.service';

describe('ReportsDashboardComponent - métricas por instrumento', () => {
  const metrics: InstrumentMetrics[] = [
    {
      instrument: 'quena',
      sessions: 12,
      avg_score: 80.5,
      avg_note_precision: 75,
      avg_tempo_accuracy: 70,
      completion_rate: 90,
    },
  ];

  function setup(instruments$: Observable<InstrumentMetrics[]>) {
    const stub = {
      getOverview: () => of({}),
      getUsersOverTime: () => of([]),
      getPracticeOverTime: () => of([]),
      getSocialOverTime: () => of({ posts: [], comments: [], likes: [] }),
      getReportsOverTime: () => of([]),
      getLessonsByCategory: () => of([]),
      getLessonsByDifficulty: () => of([]),
      getReportsByStatus: () => of([]),
      getTopLessons: () => of([]),
    };
    TestBed.configureTestingModule({
      imports: [ReportsDashboardComponent],
      providers: [
        provideNoopAnimations(),
        { provide: AnalyticsService, useValue: stub },
        {
          provide: AnalyticsAdminService,
          useValue: { getInstrumentMetrics: vi.fn().mockReturnValue(instruments$) },
        },
      ],
    });
    const fixture = TestBed.createComponent(ReportsDashboardComponent);
    fixture.detectChanges();
    return fixture;
  }

  it('consulta todos los instrumentos y los muestra en una tabla', () => {
    const fixture = setup(of(metrics));
    const admin = TestBed.inject(AnalyticsAdminService);
    expect(admin.getInstrumentMetrics).toHaveBeenCalledWith('all');
    expect(fixture.componentInstance.instrumentMetrics()).toEqual(metrics);
    const row = fixture.nativeElement.querySelector('.instrument-table tbody tr');
    expect(row.textContent).toContain('Quena');
    expect(row.textContent).toContain('12');
  });

  it('muestra estado vacío honesto si el endpoint falla, sin romper el resto', () => {
    const fixture = setup(throwError(() => new Error('500')));
    expect(fixture.componentInstance.loading()).toBe(false);
    expect(fixture.componentInstance.instrumentMetrics()).toEqual([]);
    expect(fixture.nativeElement.textContent).toContain('Sin datos de práctica por instrumento');
  });
});
