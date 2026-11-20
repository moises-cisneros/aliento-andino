import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of } from 'rxjs';

import { LessonFormComponent } from './lesson-form.component';
import { LessonService } from '../../../core/services/lesson.service';
import { CategoryService } from '../../../core/services/category.service';
import { Lesson } from '../../../core/models/lesson.model';

describe('LessonFormComponent', () => {
  let lessonService: LessonService;
  let routeId: string | null;

  function create(): ComponentFixture<LessonFormComponent> {
    const fixture = TestBed.createComponent(LessonFormComponent);
    fixture.detectChanges();
    return fixture;
  }

  beforeEach(async () => {
    routeId = null;
    await TestBed.configureTestingModule({
      imports: [LessonFormComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => routeId } } } },
        { provide: Router, useValue: { navigate: vi.fn() } },
        { provide: MatSnackBar, useValue: { open: vi.fn() } },
      ],
    }).compileComponents();

    TestBed.inject(CategoryService).loadCategories = vi.fn().mockReturnValue(of([]));
    lessonService = TestBed.inject(LessonService);
  });

  it('ofrece Quena, Zampoña y Tarka con quena por defecto', () => {
    const fixture = create();
    const options = Array.from(
      fixture.nativeElement.querySelectorAll('#instrument option') as NodeListOf<HTMLOptionElement>,
    ).map((o) => o.value);
    expect(options).toEqual(['quena', 'zampona', 'tarka']);
    expect(fixture.componentInstance.form.get('instrument')?.value).toBe('quena');
  });

  it('exige el instrumento', () => {
    const fixture = create();
    const ctrl = fixture.componentInstance.form.get('instrument')!;
    ctrl.setValue('');
    expect(ctrl.hasError('required')).toBe(true);
  });

  it('envía el instrumento elegido al crear', () => {
    const spy = vi.spyOn(lessonService, 'create').mockReturnValue(of({} as Lesson));
    const fixture = create();
    fixture.componentInstance.form.patchValue({
      title: 'Sikuri',
      category_id: 'cat-1',
      instrument: 'tarka',
    });
    fixture.componentInstance.save();
    expect(spy).toHaveBeenCalledWith(expect.objectContaining({ instrument: 'tarka' }));
  });

  it('carga el instrumento de la lección al editar y lo envía al actualizar', () => {
    routeId = 'l1';
    vi.spyOn(lessonService, 'getLesson').mockReturnValue(
      of({
        id: 'l1',
        title: 'Huayno',
        category_id: 'cat-1',
        instrument: 'zampona',
        difficulty: 'principiante',
        tempo_bpm: 90,
      } as Lesson),
    );
    const spy = vi.spyOn(lessonService, 'update').mockReturnValue(of({} as Lesson));
    const fixture = create();
    expect(fixture.componentInstance.form.get('instrument')?.value).toBe('zampona');
    fixture.componentInstance.save();
    expect(spy).toHaveBeenCalledWith('l1', expect.objectContaining({ instrument: 'zampona' }));
  });
});
