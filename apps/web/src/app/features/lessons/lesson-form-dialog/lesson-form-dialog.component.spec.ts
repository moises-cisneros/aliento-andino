import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ReactiveFormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of, throwError } from 'rxjs';

import { LessonFormDialogComponent } from './lesson-form-dialog.component';
import { LessonAdminService } from '../../../core/services/lesson-admin.service';
import { CategoryService } from '../../../core/services/category.service';
import { Lesson } from '../../../core/models/lesson.model';

describe('LessonFormDialogComponent', () => {
  let component: LessonFormDialogComponent;
  let fixture: ComponentFixture<LessonFormDialogComponent>;
  let mockLessonAdminService: {
    createLesson: ReturnType<typeof vi.fn>;
    updateLesson: ReturnType<typeof vi.fn>;
  };
  let mockCategoryService: {
    categories: ReturnType<typeof vi.fn>;
  };
  let mockSnackBar: {
    open: ReturnType<typeof vi.fn>;
  };
  let mockDialogRef: {
    close: ReturnType<typeof vi.fn>;
  };

  const mockLesson: Lesson = {
    id: 'lesson-123',
    category_id: 'cat-456',
    title: 'Escala de Sol Mayor en Quena',
    description: 'Aprender la digitación básica de la primera octava.',
    instrument: 'quena',
    difficulty: 'principiante',
    tempo_bpm: 80,
    time_signature: '4/4',
    key_signature: 'G',
    genre: 'Yaraví',
    artist: 'Tradicional',
    thumbnail_url: null,
    audio_preview_url: null,
    duration_seconds: 60,
    order: 1,
    is_active: true,
    is_premium: false,
    total_plays: 5,
    average_score: 95,
    created_by: 'admin',
    created_at: new Date().toISOString(),
    updated_at: null,
    category_name: 'Escalas Andinas',
    notes_count: 2,
    notes: [
      {
        id: 'n1',
        lesson_id: 'lesson-123',
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
      {
        id: 'n2',
        lesson_id: 'lesson-123',
        position: 2,
        note: 'A4',
        duration: 1.0,
        is_rest: false,
        is_chord: false,
        chord_group: null,
        velocity: 80,
        finger: null,
        hand: null,
        has_breath_mark: true,
        created_at: new Date().toISOString(),
      },
    ],
  };

  beforeEach(async () => {
    mockLessonAdminService = {
      createLesson: vi.fn().mockReturnValue(of(mockLesson)),
      updateLesson: vi.fn().mockReturnValue(of(mockLesson)),
    };

    mockCategoryService = {
      categories: vi.fn().mockReturnValue([
        { id: 'cat-456', name: 'Escalas Andinas' },
        { id: 'cat-789', name: 'Melodías Tradicionales' },
      ]),
    };

    mockSnackBar = {
      open: vi.fn(),
    };

    mockDialogRef = {
      close: vi.fn(),
    };

    await TestBed.configureTestingModule({
      imports: [LessonFormDialogComponent, ReactiveFormsModule],
      providers: [
        { provide: LessonAdminService, useValue: mockLessonAdminService },
        { provide: CategoryService, useValue: mockCategoryService },
        { provide: MatSnackBar, useValue: mockSnackBar },
        { provide: MatDialogRef, useValue: mockDialogRef },
        { provide: MAT_DIALOG_DATA, useValue: null },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(LessonFormDialogComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('debe crear el componente correctamente', () => {
    expect(component).toBeTruthy();
    expect(component.form).toBeDefined();
  });

  describe('Validadores del formulario reactivo', () => {
    it('debe marcar el formulario como inválido cuando los campos obligatorios están vacíos', () => {
      component.form.patchValue({
        title: '',
        description: '',
        category_id: '',
        tempo_bpm: null,
      });

      expect(component.form.valid).toBe(false);
      expect(component.form.get('title')?.hasError('required')).toBe(true);
      expect(component.form.get('description')?.hasError('required')).toBe(true);
      expect(component.form.get('category_id')?.hasError('required')).toBe(true);
      expect(component.form.get('tempo_bpm')?.hasError('required')).toBe(true);
    });

    it('debe validar que el título tenga al menos 3 caracteres', () => {
      const titleControl = component.form.get('title');
      titleControl?.setValue('ab');
      expect(titleControl?.hasError('minlength')).toBe(true);

      titleControl?.setValue('abc');
      expect(titleControl?.hasError('minlength')).toBe(false);
    });

    it('debe validar que el tempo BPM esté entre 40 y 200', () => {
      const tempoControl = component.form.get('tempo_bpm');

      tempoControl?.setValue(30);
      expect(tempoControl?.hasError('min')).toBe(true);

      tempoControl?.setValue(210);
      expect(tempoControl?.hasError('max')).toBe(true);

      tempoControl?.setValue(120);
      expect(tempoControl?.valid).toBe(true);
    });

    it('debe establecer valores por defecto válidos para instrumento andino y dificultad', () => {
      expect(component.form.get('instrument')?.value).toBe('quena');
      expect(component.form.get('difficulty')?.value).toBe('principiante');
    });
  });

  describe('Editor interactivo de notas y marcas de respiración', () => {
    it('debe iniciar con lista de notas vacía y advertencia visible', () => {
      expect(component.notes().length).toBe(0);
      const compiled = fixture.nativeElement as HTMLElement;
      const warning = compiled.querySelector('#empty-notes-warning');
      expect(warning?.textContent).toContain(
        'Debe agregar al menos una nota musical a la secuencia',
      );
    });

    it('debe deshabilitar el botón de guardado cuando no hay notas en la secuencia', () => {
      // Llenar formulario válido
      component.form.patchValue({
        title: 'Lección Válida',
        description: 'Descripción completa',
        category_id: 'cat-456',
        instrument: 'quena',
        difficulty: 'principiante',
        tempo_bpm: 100,
      });
      fixture.detectChanges();

      expect(component.form.valid).toBe(true);
      expect(component.notes().length).toBe(0);

      const saveButton = fixture.nativeElement.querySelector('.btn-save') as HTMLButtonElement;
      expect(saveButton.disabled).toBe(true);
    });

    it('debe agregar una nota musical con notación científica y duración al invocar addNote()', () => {
      component.newNoteTone = 'G4';
      component.newNoteDuration = 1.0;
      component.newNoteBreath = true;

      component.addNote();

      expect(component.notes().length).toBe(1);
      expect(component.notes()[0]).toEqual({
        position: 1,
        note: 'G4',
        duration: 1.0,
        is_rest: false,
        has_breath_mark: true,
        velocity: 80,
      });
      // El flag de respiración se resetea para la siguiente nota
      expect(component.newNoteBreath).toBe(false);
    });

    it('debe agregar un silencio musical al invocar addRest()', () => {
      component.newNoteDuration = 0.5;
      component.addRest();

      expect(component.notes().length).toBe(1);
      expect(component.notes()[0].is_rest).toBe(true);
      expect(component.notes()[0].note).toBe('REST');
      expect(component.notes()[0].duration).toBe(0.5);
    });

    it('debe alternar la marca de respiración al invocar toggleBreathMark()', () => {
      component.newNoteTone = 'D5';
      component.newNoteBreath = false;
      component.addNote();

      expect(component.notes()[0].has_breath_mark).toBe(false);

      component.toggleBreathMark(0);
      expect(component.notes()[0].has_breath_mark).toBe(true);

      component.toggleBreathMark(0);
      expect(component.notes()[0].has_breath_mark).toBe(false);
    });

    it('debe remover una nota y reordenar las posiciones correlativas', () => {
      component.newNoteTone = 'G4';
      component.addNote();
      component.newNoteTone = 'A4';
      component.addNote();
      component.newNoteTone = 'B4';
      component.addNote();

      expect(component.notes().length).toBe(3);

      // Eliminar segunda nota (A4)
      component.removeNote(1);

      expect(component.notes().length).toBe(2);
      expect(component.notes()[0].note).toBe('G4');
      expect(component.notes()[0].position).toBe(1);
      expect(component.notes()[1].note).toBe('B4');
      expect(component.notes()[1].position).toBe(2);
    });
  });

  describe('Guardado y manejo de errores (SUB-05-A)', () => {
    beforeEach(() => {
      component.form.patchValue({
        title: 'El Cóndor Pasa - Escala en Quena',
        description: 'Ejercicio de digitación andina.',
        instrument: 'quena',
        category_id: 'cat-456',
        difficulty: 'principiante',
        tempo_bpm: 85,
        time_signature: '4/4',
        key_signature: 'G',
        genre: 'Huayno',
      });
      component.newNoteTone = 'G4';
      component.addNote();
      fixture.detectChanges();
    });

    it('debe enviar LessonCreate a lessonAdminService.createLesson y cerrar el diálogo al éxito', () => {
      component.save();

      expect(mockLessonAdminService.createLesson).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'El Cóndor Pasa - Escala en Quena',
          instrument: 'quena',
          notes: expect.arrayContaining([expect.objectContaining({ note: 'G4', position: 1 })]),
        }),
      );
      expect(mockSnackBar.open).toHaveBeenCalledWith(
        'Lección creada con éxito',
        'Cerrar',
        expect.any(Object),
      );
      expect(mockDialogRef.close).toHaveBeenCalledWith(mockLesson);
    });

    it('debe mostrar toast de falta de privilegios administrativos en error 401/403', () => {
      mockLessonAdminService.createLesson.mockReturnValue(
        throwError(() => ({ status: 403, error: { detail: 'Forbidden' } })),
      );

      component.save();

      expect(component.saving()).toBe(false);
      expect(mockSnackBar.open).toHaveBeenCalledWith(
        'Falta de privilegios administrativos para gestionar lecciones',
        'Cerrar',
        expect.any(Object),
      );
    });

    it('no debe enviar el formulario si no hay notas en la secuencia', () => {
      component.notes.set([]);
      component.save();

      expect(mockLessonAdminService.createLesson).not.toHaveBeenCalled();
      expect(mockSnackBar.open).toHaveBeenCalledWith(
        'Debe agregar al menos una nota musical a la secuencia',
        'Cerrar',
        expect.any(Object),
      );
    });
  });

  describe('Modo Edición', () => {
    it('debe inicializarse con los datos de la lección a editar y llamar updateLesson al guardar', () => {
      component.lessonToEdit = mockLesson;
      component.ngOnInit();

      expect(component.isEdit()).toBe(true);
      expect(component.form.get('title')?.value).toBe('Escala de Sol Mayor en Quena');
      expect(component.notes().length).toBe(2);
      expect(component.notes()[1].has_breath_mark).toBe(true);

      component.save();

      expect(mockLessonAdminService.updateLesson).toHaveBeenCalledWith(
        'lesson-123',
        expect.objectContaining({
          title: 'Escala de Sol Mayor en Quena',
        }),
      );
      expect(mockSnackBar.open).toHaveBeenCalledWith(
        'Lección actualizada con éxito',
        'Cerrar',
        expect.any(Object),
      );
    });
  });
});
