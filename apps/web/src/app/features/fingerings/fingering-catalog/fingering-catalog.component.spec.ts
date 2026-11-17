import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of, throwError } from 'rxjs';

import { FingeringCatalogComponent } from './fingering-catalog.component';
import { FingeringAdminService } from '../../../core/services/fingering-admin.service';
import { Fingering } from '../../../core/models/fingering.model';

describe('FingeringCatalogComponent', () => {
  let component: FingeringCatalogComponent;
  let fixture: ComponentFixture<FingeringCatalogComponent>;
  let fingeringService: FingeringAdminService;
  let snackBarMock: { open: ReturnType<typeof vi.fn> };

  const mockFingeringList: Fingering[] = [
    {
      id: 'f-1',
      instrument: 'quena',
      note: 'G',
      octave: 4,
      holes_covered: [1, 1, 1, 1, 1, 1, 1],
      is_alternate: false,
      description: 'Sol4 fundamental',
      created_at: new Date().toISOString(),
    },
    {
      id: 'f-2',
      instrument: 'quena',
      note: 'A',
      octave: 4,
      holes_covered: [1, 1, 1, 1, 1, 0, 0],
      is_alternate: true,
      description: 'La4 alterna',
      created_at: new Date().toISOString(),
    },
  ];

  beforeEach(async () => {
    snackBarMock = {
      open: vi.fn(),
    };

    await TestBed.configureTestingModule({
      imports: [FingeringCatalogComponent],
      providers: [
        FingeringAdminService,
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: MatSnackBar, useValue: snackBarMock },
      ],
    }).compileComponents();

    fingeringService = TestBed.inject(FingeringAdminService);
    vi.spyOn(fingeringService, 'getFingerings').mockReturnValue(of(mockFingeringList));

    fixture = TestBed.createComponent(FingeringCatalogComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('debe crear el componente correctamente', () => {
    expect(component).toBeTruthy();
    expect(component.selectedInstrument()).toBe('quena');
    expect(component.holesCovered().length).toBe(7);
  });

  it('debe inicializar y cargar la lista de digitaciones en el catálogo', () => {
    expect(fingeringService.getFingerings).toHaveBeenCalledWith('all');
  });

  it('debe cambiar de instrumento a Tarka y configurar 6 orificios', () => {
    component.onSelectInstrument('tarka');

    expect(component.selectedInstrument()).toBe('tarka');
    expect(component.holesCovered().length).toBe(6);
    expect(component.selectedNote()).toBe('C');
    expect(component.selectedOctave()).toBe(5);
  });

  it('debe cambiar de instrumento a Zampoña y configurar 13 tubos', () => {
    component.onSelectInstrument('zampona');

    expect(component.selectedInstrument()).toBe('zampona');
    expect(component.holesCovered().length).toBe(13);
  });

  it('debe alternar el estado de un orificio al hacer clic (toggleHole)', () => {
    // Inicialmente [1, 1, 1, 1, 1, 1, 1]
    expect(component.holesCovered()[0]).toBe(1);

    component.toggleHole(0);
    expect(component.holesCovered()[0]).toBe(0);

    component.toggleHole(0);
    expect(component.holesCovered()[0]).toBe(1);
  });

  it('debe limpiar todos los orificios con resetHoles', () => {
    component.resetHoles();
    expect(component.holesCovered().every((h) => h === 0)).toBe(true);
  });

  it('debe calcular la notación científica compuesta correctamente', () => {
    component.selectedNote.set('F#');
    component.selectedOctave.set(5);

    expect(component.currentScientificNote()).toBe('F#5');
  });

  it('debe guardar digitación exitosamente y mostrar snackbar de éxito', () => {
    const createdFingering: Fingering = {
      id: 'f-new-3',
      instrument: 'quena',
      note: 'G',
      octave: 4,
      holes_covered: [1, 1, 1, 1, 1, 1, 1],
      is_alternate: false,
      created_at: new Date().toISOString(),
    };

    const createSpy = vi
      .spyOn(fingeringService, 'createFingering')
      .mockReturnValue(of(createdFingering));

    component.saveFingering();

    expect(createSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        instrument: 'quena',
        note: 'G',
        octave: 4,
        is_alternate: false,
      }),
    );
    expect(snackBarMock.open).toHaveBeenCalledWith(
      'Digitación guardada exitosamente en el catálogo',
      'Aceptar',
      expect.any(Object),
    );
  });

  it('debe manejar error 409 de unicidad mostrando mensaje de digitación principal duplicada (RF-04 / S9)', () => {
    vi.spyOn(fingeringService, 'createFingering').mockReturnValue(
      throwError(() => ({
        status: 409,
        error: { detail: 'Digitación principal ya registrada para esta nota' },
      })),
    );

    component.saveFingering();

    expect(snackBarMock.open).toHaveBeenCalledWith(
      'Digitación principal ya registrada para esta nota',
      'Entendido',
      expect.objectContaining({ duration: 5000 }),
    );
    expect(component.isSaving()).toBe(false);
  });

  it('debe manejar error 403 notificando falta de privilegios administrativos', () => {
    vi.spyOn(fingeringService, 'createFingering').mockReturnValue(
      throwError(() => ({
        status: 403,
        error: { detail: 'No autorizado' },
      })),
    );

    component.saveFingering();

    expect(snackBarMock.open).toHaveBeenCalledWith(
      'No tiene privilegios administrativos para modificar el catálogo',
      'Cerrar',
      expect.any(Object),
    );
  });

  it('debe solicitar confirmación y eliminar una digitación del catálogo', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    const deleteSpy = vi.spyOn(fingeringService, 'deleteFingering').mockReturnValue(of(void 0));

    component.deleteFingering('f-1');

    expect(deleteSpy).toHaveBeenCalledWith('f-1');
    expect(snackBarMock.open).toHaveBeenCalledWith(
      'Digitación eliminada correctamente',
      'Aceptar',
      expect.any(Object),
    );
  });
});
