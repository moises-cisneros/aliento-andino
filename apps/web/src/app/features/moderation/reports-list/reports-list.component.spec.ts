import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of, throwError } from 'rxjs';

import { ReportsListComponent } from './reports-list.component';
import { ModerationService } from '../../../core/services/moderation.service';
import { Report, PaginatedResponse } from '../../../core/models/social.model';

function makeReport(overrides: Partial<Report> = {}): Report {
  return {
    id: 'report-1',
    reporter: { id: 'u1', username: 'ana', full_name: 'Ana Quispe', avatar_url: null },
    post_id: 'post-1',
    comment_id: null,
    reported_user_id: null,
    reason: 'spam',
    description: null,
    status: 'pending',
    reviewed_by: null,
    reviewed_at: null,
    created_at: new Date('2026-01-15T10:00:00Z').toISOString(),
    post_content: 'Contenido reportado de ejemplo',
    comment_content: null,
    reported_username: null,
    ...overrides,
  };
}

function paginated(items: Report[], total = items.length): PaginatedResponse<Report> {
  return { items, total, page: 1, pages: 1 };
}

describe('ReportsListComponent', () => {
  let component: ReportsListComponent;
  let fixture: ComponentFixture<ReportsListComponent>;
  let reportsSignal = signal<Report[]>([]);
  let totalReportsSignal = signal(0);
  let mockModerationService: {
    reports: typeof reportsSignal;
    totalReports: typeof totalReportsSignal;
    loadReports: ReturnType<typeof vi.fn>;
    updateReportStatus: ReturnType<typeof vi.fn>;
  };
  let mockSnackBar: { open: ReturnType<typeof vi.fn> };
  let mockDialog: { open: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    reportsSignal = signal<Report[]>([makeReport()]);
    totalReportsSignal = signal(1);

    mockModerationService = {
      reports: reportsSignal,
      totalReports: totalReportsSignal,
      loadReports: vi.fn().mockReturnValue(of(paginated([makeReport()]))),
      updateReportStatus: vi.fn().mockReturnValue(of(makeReport({ status: 'resolved' }))),
    };
    mockSnackBar = { open: vi.fn() };
    mockDialog = { open: vi.fn().mockReturnValue({ afterClosed: () => of(null) }) };

    await TestBed.configureTestingModule({
      imports: [ReportsListComponent],
      providers: [
        { provide: ModerationService, useValue: mockModerationService },
        { provide: MatSnackBar, useValue: mockSnackBar },
        { provide: MatDialog, useValue: mockDialog },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ReportsListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges(); // dispara ngOnInit -> loadData
  });

  it('debe crear el componente y cargar los reportes al iniciar', () => {
    expect(component).toBeTruthy();
    expect(mockModerationService.loadReports).toHaveBeenCalledWith({
      page: 1,
      limit: 10,
      status: undefined,
      reason: undefined,
    });
  });

  it('debe renderizar una fila por reporte con el nombre de quien reporta', () => {
    const compiled = fixture.nativeElement as HTMLElement;
    const rows = compiled.querySelectorAll('tbody tr');
    expect(rows.length).toBe(1);
    expect(compiled.textContent).toContain('Ana Quispe');
  });

  describe('Filtros por estado y motivo', () => {
    it('applyFilters reinicia a la primera página y recarga con los filtros activos', () => {
      component.currentPage = 3;
      component.selectedStatus = 'pending';
      component.selectedReason = 'spam';

      component.applyFilters();

      expect(component.currentPage).toBe(1);
      expect(mockModerationService.loadReports).toHaveBeenLastCalledWith({
        page: 1,
        limit: 10,
        status: 'pending',
        reason: 'spam',
      });
    });
  });

  describe('Paginación', () => {
    it('totalPages se calcula a partir del total y el tamaño de página', () => {
      totalReportsSignal.set(25);
      component.pageSize = 10;
      expect(component.totalPages()).toBe(3);
    });

    it('changePage avanza de página y recarga', () => {
      component.changePage(1);
      expect(component.currentPage).toBe(2);
      expect(mockModerationService.loadReports).toHaveBeenLastCalledWith(
        expect.objectContaining({ page: 2 }),
      );
    });
  });

  describe('Acciones inmediatas de moderación con auditoría', () => {
    it('resolve marca el reporte como "resolved", avisa y recarga', () => {
      component.resolve(makeReport({ id: 'report-9' }));

      expect(mockModerationService.updateReportStatus).toHaveBeenCalledWith('report-9', 'resolved');
      expect(mockSnackBar.open).toHaveBeenCalledWith('Reporte resuelto', 'OK', expect.any(Object));
    });

    it('dismiss marca el reporte como "dismissed"', () => {
      component.dismiss(makeReport({ id: 'report-7' }));

      expect(mockModerationService.updateReportStatus).toHaveBeenCalledWith(
        'report-7',
        'dismissed',
      );
    });

    it('ante un fallo de conexión o token revocado muestra un mensaje claro', () => {
      mockModerationService.updateReportStatus.mockReturnValue(
        throwError(() => ({ error: { detail: 'Token revocado' } })),
      );

      component.resolve(makeReport());

      expect(mockSnackBar.open).toHaveBeenCalledWith('Token revocado', 'OK', expect.any(Object));
    });
  });

  describe('Etiquetas legibles', () => {
    it('traduce motivos y estados a español y cae al valor crudo si es desconocido', () => {
      expect(component.reasonLabel('harassment')).toBe('Acoso');
      expect(component.statusLabel('resolved')).toBe('Resuelto');
      expect(component.reasonLabel('desconocido')).toBe('desconocido');
    });
  });

  describe('Detalle de reporte', () => {
    it('openDetail abre el diálogo y recarga cuando hubo cambios', () => {
      mockDialog.open.mockReturnValue({ afterClosed: () => of(true) });
      const callsBefore = mockModerationService.loadReports.mock.calls.length;

      component.openDetail(makeReport());

      expect(mockDialog.open).toHaveBeenCalled();
      expect(mockModerationService.loadReports.mock.calls.length).toBe(callsBefore + 1);
    });
  });
});
