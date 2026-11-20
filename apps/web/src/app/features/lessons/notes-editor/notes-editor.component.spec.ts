import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { ActivatedRoute } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of } from 'rxjs';

import { NotesEditorComponent } from './notes-editor.component';
import { LessonService } from '../../../core/services/lesson.service';
import { FingeringAdminService } from '../../../core/services/fingering-admin.service';
import { Fingering } from '../../../core/models/fingering.model';
import { Lesson, NoteSequence } from '../../../core/models/lesson.model';

describe('NotesEditorComponent', () => {
  let fixture: ComponentFixture<NotesEditorComponent>;
  let component: NotesEditorComponent;
  let lessonService: LessonService;
  let fingeringService: FingeringAdminService;

  const catalog: Fingering[] = [
    {
      id: 'f-g4-alt',
      instrument: 'zampona',
      note: 'G',
      octave: 4,
      holes_covered: [0, 1],
      is_alternate: true,
      created_at: '',
    },
    {
      id: 'f-g4',
      instrument: 'zampona',
      note: 'G',
      octave: 4,
      holes_covered: [1, 1, 0],
      is_alternate: false,
      description: 'Sol4',
      created_at: '',
    },
    {
      id: 'f-fs5',
      instrument: 'zampona',
      note: 'F#',
      octave: 5,
      holes_covered: [1, 0],
      is_alternate: false,
      created_at: '',
    },
  ];

  const storedNote: NoteSequence = {
    id: 'n1',
    lesson_id: 'l1',
    position: 0,
    note: 'G4',
    duration: 1,
    is_rest: false,
    breath_mark: true,
    velocity: 80,
    created_at: '',
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [NotesEditorComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => 'l1' } } } },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
      ],
    }).compileComponents();

    lessonService = TestBed.inject(LessonService);
    fingeringService = TestBed.inject(FingeringAdminService);
    vi.spyOn(lessonService, 'getLesson').mockReturnValue(
      of({ id: 'l1', title: 'Huayno', instrument: 'zampona' } as Lesson),
    );
    vi.spyOn(lessonService, 'getLessonNotes').mockReturnValue(of([storedNote]));
    vi.spyOn(fingeringService, 'getFingerings').mockImplementation(() => {
      fingeringService.fingerings.set(catalog);
      return of(catalog);
    });

    fixture = TestBed.createComponent(NotesEditorComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('carga las digitaciones del instrumento de la lección', () => {
    expect(fingeringService.getFingerings).toHaveBeenCalledWith('zampona');
    expect(component.instrumentLabel()).toBe('Zampoña');
  });

  it('no expone controles no aerófonos en el FormGroup de cada nota', () => {
    const keys = Object.keys(component.getGroup(0).controls).sort();
    expect(keys).toEqual(['breath_mark', 'duration', 'is_rest', 'note']);
  });

  it('no renderiza selectores de dedo, mano, acorde ni velocidad', () => {
    const html: string = fixture.nativeElement.innerHTML;
    for (const key of ['finger', 'hand', 'is_chord', 'chord_group', 'velocity']) {
      expect(html).not.toContain(`formcontrolname="${key}"`);
    }
    expect(html).not.toContain('Acorde');
    expect((component as unknown as Record<string, unknown>)['addChord']).toBeUndefined();
  });

  it('muestra el control de marca de respiración con el valor cargado', () => {
    expect(
      fixture.nativeElement.querySelector('input[formcontrolname="breath_mark"]'),
    ).toBeTruthy();
    expect(component.getGroup(0).get('breath_mark')?.value).toBe(true);
  });

  it('previsualiza la digitación principal de la nota seleccionada', () => {
    component.selectNote(0);
    fixture.detectChanges();
    expect(component.selectedFingering()?.id).toBe('f-g4');
    expect(fixture.nativeElement.querySelectorAll('.hole').length).toBe(3);
  });

  it('resuelve notas con bemol a su equivalente sostenido', () => {
    expect(component.findFingering('Gb5')?.id).toBe('f-fs5');
    expect(component.findFingering('F#5')?.id).toBe('f-fs5');
  });

  it('informa cuando la nota no tiene digitación en el catálogo', () => {
    component.addNote();
    component.getGroup(1).patchValue({ note: 'C6' });
    component.syncSelectedNote();
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('Sin digitación registrada');
  });

  it('addBreath marca la última nota con respiración', () => {
    component.addNote();
    component.addBreath();
    expect(component.getGroup(1).get('breath_mark')?.value).toBe(true);
  });

  it('guarda notas con position, breath_mark y fingering_id (contrato backend)', () => {
    const spy = vi.spyOn(lessonService, 'updateNotes').mockReturnValue(of([]));
    component.addRest();
    component.saveNotes();
    expect(spy).toHaveBeenCalledWith('l1', [
      {
        position: 0,
        note: 'G4',
        duration: 1,
        is_rest: false,
        breath_mark: true,
        fingering_id: 'f-g4',
      },
      {
        position: 1,
        note: 'REST',
        duration: 1,
        is_rest: true,
        breath_mark: false,
        fingering_id: null,
      },
    ]);
  });
});
