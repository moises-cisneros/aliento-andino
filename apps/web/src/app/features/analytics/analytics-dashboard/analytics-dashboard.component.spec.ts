import { ComponentFixture, TestBed } from '@angular/core/testing';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of, throwError } from 'rxjs';

import { AnalyticsDashboardComponent } from './analytics-dashboard.component';
import {
  AnalyticsAdminService,
  InstrumentMetrics,
} from '../../../core/services/analytics-admin.service';

const rows: InstrumentMetrics[] = [
  {
    instrument: 'quena',
    sessions: 3,
    avg_score: 88,
    avg_note_precision: 0.8,
    avg_tempo_accuracy: 0.9,
    completion_rate: 0.66,
  },
  {
    instrument: 'zampona',
    sessions: 1,
    avg_score: 70,
    avg_note_precision: 0.6,
    avg_tempo_accuracy: 0.8,
    completion_rate: 1,
  },
];

describe('AnalyticsDashboardComponent', () => {
  let component: AnalyticsDashboardComponent;
  let fixture: ComponentFixture<AnalyticsDashboardComponent>;
  let mockService: {
    getInstrumentMetrics: ReturnType<typeof vi.fn>;
    exportMetricsCsv: ReturnType<typeof vi.fn>;
  };
  let mockSnackBar: { open: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockService = {
      getInstrumentMetrics: vi.fn().mockReturnValue(of(rows)),
      exportMetricsCsv: vi.fn().mockReturnValue(of(new Blob(['csv'], { type: 'text/csv' }))),
    };
    mockSnackBar = { open: vi.fn() };

    // jsdom no implementa createObjectURL/revokeObjectURL.
    Object.defineProperty(URL, 'createObjectURL', {
      value: vi.fn().mockReturnValue('blob:mock'),
      writable: true,
      configurable: true,
    });
    Object.defineProperty(URL, 'revokeObjectURL', {
      value: vi.fn(),
      writable: true,
      configurable: true,
    });

    await TestBed.configureTestingModule({
      imports: [AnalyticsDashboardComponent],
      providers: [
        { provide: AnalyticsAdminService, useValue: mockService },
        { provide: MatSnackBar, useValue: mockSnackBar },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AnalyticsDashboardComponent);
    component = fixture.componentInstance;
    fixture.detectChanges(); // dispara ngOnInit -> load
  });

  it('renderiza una tarjeta por instrumento con sus señales de métricas', () => {
    expect(mockService.getInstrumentMetrics).toHaveBeenCalledWith('all');

    const cards = fixture.nativeElement.querySelectorAll('[data-test="metric-card"]');
    expect(cards.length).toBe(2);
    expect(fixture.nativeElement.textContent).toContain('Quena');
    expect(fixture.nativeElement.textContent).toContain('80%'); // precisión 0.8 -> 80%
  });

  it('al cambiar de instrumento actualiza la señal y recarga', () => {
    component.onInstrumentChange('zampona');

    expect(component.instrument()).toBe('zampona');
    expect(mockService.getInstrumentMetrics).toHaveBeenLastCalledWith('zampona');
  });

  it('muestra el estado vacío cuando no hay métricas', () => {
    mockService.getInstrumentMetrics.mockReturnValue(of([]));
    component.load();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-test="empty"]')).toBeTruthy();
  });

  it('exportar CSV con éxito invoca el servicio sin mostrar error', () => {
    component.exportCsv();

    expect(mockService.exportMetricsCsv).toHaveBeenCalledWith('all');
    expect(mockSnackBar.open).not.toHaveBeenCalled();
  });

  it('ante un fallo de exportación muestra un toast claro', () => {
    mockService.exportMetricsCsv.mockReturnValue(throwError(() => new Error('fail')));

    component.exportCsv();

    expect(mockSnackBar.open).toHaveBeenCalledWith(
      'Error al generar archivo de exportación',
      'OK',
      expect.any(Object),
    );
  });
});
