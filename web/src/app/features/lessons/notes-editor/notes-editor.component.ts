import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormArray, FormGroup, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { CdkDragDrop, DragDropModule, moveItemInArray } from '@angular/cdk/drag-drop';
import {
  LucideArrowLeft,
  LucideSave,
  LucidePlus,
  LucidePause,
  LucideMusic,
  LucideTrash2,
  LucideCopy,
  LucideGripVertical,
  LucideVolumeX,
} from '@lucide/angular';

import { LessonService } from '../../../core/services/lesson.service';
import { NoteSequence, NoteSequenceCreate } from '../../../core/models/lesson.model';

@Component({
  selector: 'app-notes-editor',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    DragDropModule,
    LucideArrowLeft, LucideSave, LucidePlus, LucidePause, LucideMusic,
    LucideTrash2, LucideCopy, LucideGripVertical, LucideVolumeX,
  ],
  template: `
    <div class="notes-editor">
      <div class="header-row">
        <div>
          <h2>Editor de Notas</h2>
          <p class="subtitle">{{ lessonTitle() }} — {{ notesArray.length }} notas</p>
        </div>
        <div class="header-actions">
          <button class="btn btn-ghost" (click)="goBack()">
            <svg lucideArrowLeft [size]="16"></svg> Volver
          </button>
          <button class="btn btn-primary" (click)="saveNotes()"
            [disabled]="saving() || notesArray.length === 0">
            <svg lucideSave [size]="16"></svg>
            {{ saving() ? 'Guardando...' : 'Guardar Todo' }}
          </button>
        </div>
      </div>

      <!-- Barra de acciones -->
      <div class="quick-actions">
        <button class="btn" (click)="addNote()">
          <svg lucidePlus [size]="16"></svg> Nota
        </button>
        <button class="btn" (click)="addRest()">
          <svg lucidePause [size]="16"></svg> Silencio
        </button>
        <button class="btn" (click)="addChord()">
          <svg lucideMusic [size]="16"></svg> Acorde (3 notas)
        </button>
        <button class="btn btn-danger" (click)="clearAll()" [disabled]="notesArray.length === 0">
          <svg lucideTrash2 [size]="16"></svg> Limpiar Todo
        </button>
      </div>

      <!-- Preview visual -->
      <div class="notes-preview">
        @for (ctrl of notesArray.controls; track $index) {
          <div class="preview-note"
            [class.preview-rest]="ctrl.get('is_rest')?.value"
            [class.preview-chord]="ctrl.get('is_chord')?.value"
            [class.preview-current]="$index === selectedIndex()"
            (click)="selectedIndex.set($index)"
            [title]="ctrl.get('note')?.value + ' (' + ctrl.get('duration')?.value + ')'"
          >
            {{ ctrl.get('is_rest')?.value ? '—' : ctrl.get('note')?.value }}
          </div>
        }
      </div>

      <!-- Lista drag & drop -->
      <div class="notes-list" cdkDropList (cdkDropListDropped)="onDrop($event)">
        @for (ctrl of notesArray.controls; track $index; let i = $index) {
          <div class="note-row" cdkDrag
            [class.selected-row]="i === selectedIndex()"
            (click)="selectedIndex.set(i)">

            <div class="drag-handle" cdkDragHandle>
              <svg lucideGripVertical [size]="16"></svg>
            </div>

            <span class="note-position">{{ i + 1 }}</span>

            <div class="note-fields" [formGroup]="getGroup(i)">
              <div class="form-group field-note">
                <input class="form-input" formControlName="note"
                  [readonly]="ctrl.get('is_rest')?.value"
                  placeholder="C4" />
              </div>

              <div class="form-group field-sm">
                <select class="form-select" formControlName="duration">
                  <option [value]="0.25">1/16</option>
                  <option [value]="0.5">1/8</option>
                  <option [value]="1">1/4</option>
                  <option [value]="1.5">3/8</option>
                  <option [value]="2">1/2</option>
                  <option [value]="4">1/1</option>
                </select>
              </div>

              <div class="form-group field-sm">
                <input class="form-input" formControlName="velocity" type="number" placeholder="Vel" />
              </div>

              <div class="form-group field-xs">
                <select class="form-select" formControlName="finger">
                  <option [ngValue]="null">—</option>
                  <option [value]="1">1</option>
                  <option [value]="2">2</option>
                  <option [value]="3">3</option>
                  <option [value]="4">4</option>
                  <option [value]="5">5</option>
                </select>
              </div>

              <div class="form-group field-xs">
                <select class="form-select" formControlName="hand">
                  <option [ngValue]="null">—</option>
                  <option value="left">Izq</option>
                  <option value="right">Der</option>
                  <option value="both">Ambas</option>
                </select>
              </div>

              <label class="checkbox">
                <input type="checkbox" formControlName="is_rest" (change)="onRestChange(i)" />
                <span>Sil</span>
              </label>
              <label class="checkbox">
                <input type="checkbox" formControlName="is_chord" />
                <span>Aco</span>
              </label>

              @if (ctrl.get('is_chord')?.value) {
                <div class="form-group field-xs">
                  <input class="form-input" formControlName="chord_group" type="number" placeholder="Grp" />
                </div>
              }
            </div>

            <div class="row-actions">
              <button class="btn-icon" title="Duplicar" (click)="duplicateNote(i); $event.stopPropagation()">
                <svg lucideCopy [size]="14"></svg>
              </button>
              <button class="btn-icon danger" title="Eliminar" (click)="removeNote(i); $event.stopPropagation()">
                <svg lucideTrash2 [size]="14"></svg>
              </button>
            </div>
          </div>
        }
      </div>

      @if (notesArray.length === 0) {
        <div class="empty-state">
          <svg lucideVolumeX [size]="48" class="text-muted"></svg>
          <p>No hay notas. Agrega notas usando los botones de arriba.</p>
        </div>
      }
    </div>
  `,
  styles: [`
    .notes-editor { max-width: 1200px; margin: 0 auto; }
    .header-row { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
    .header-row h2 { color: var(--text-secondary); margin: 0; }
    .subtitle { color: var(--text-muted); font-size: 14px; margin: 4px 0 0; }
    .header-actions { display: flex; gap: 8px; }

    .quick-actions { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }

    .notes-preview {
      display: flex; gap: 3px; overflow-x: auto; padding: 8px; margin-bottom: 16px;
      background: var(--bg-surface-alt); border-radius: 8px;
    }
    .preview-note {
      min-width: 36px; height: 28px; display: flex; align-items: center; justify-content: center;
      background: var(--color-primary-subtle); color: var(--color-primary); border-radius: 4px;
      font-size: 11px; cursor: pointer; user-select: none; padding: 0 4px;
    }
    .preview-rest { background: rgba(100, 116, 139, 0.15); color: var(--text-dimmed); }
    .preview-chord { background: rgba(124, 58, 237, 0.15); color: var(--color-purple); }
    .preview-current { outline: 2px solid var(--color-primary); }

    .note-row {
      display: flex; align-items: center; gap: 8px; padding: 8px 12px;
      border-radius: 8px; margin-bottom: 4px; cursor: pointer;
      border: 1px solid transparent;
    }
    .note-row.selected-row { border-color: var(--color-primary); }
    .drag-handle { cursor: grab; color: var(--text-dimmed); display: flex; align-items: center; }
    .note-position { color: var(--text-dimmed); font-size: 12px; min-width: 24px; text-align: center; }
    .note-fields { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; flex: 1; }

    .note-fields .form-group { margin-bottom: 0; }
    .note-fields .form-input,
    .note-fields .form-select { padding: 6px 8px; font-size: 13px; }

    .field-note { width: 80px; }
    .field-sm { width: 70px; }
    .field-xs { width: 60px; }
    .row-actions { display: flex; gap: 2px; }

    .cdk-drag-preview { box-shadow: 0 4px 20px rgba(0,0,0,0.4); }
    .cdk-drag-placeholder { opacity: 0.3; }

    .empty-state { text-align: center; padding: 48px; color: var(--text-muted); }
    .empty-state p { margin-top: 12px; }

    .checkbox { font-size: 12px; gap: 4px; }
    .checkbox input[type="checkbox"] { width: 14px; height: 14px; }
  `],
})
export class NotesEditorComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly lessonService = inject(LessonService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);

  readonly lessonTitle = signal('');
  readonly saving = signal(false);
  readonly selectedIndex = signal(0);

  private lessonId = '';
  form!: FormGroup;

  private readonly notePattern = /^([A-G][#b]?[0-8]|REST)$/;

  get notesArray(): FormArray {
    return this.form.get('notes') as FormArray;
  }

  ngOnInit(): void {
    this.form = this.fb.group({
      notes: this.fb.array([]),
    });

    this.lessonId = this.route.snapshot.paramMap.get('id')!;

    this.lessonService.getLesson(this.lessonId).subscribe({
      next: (lesson) => this.lessonTitle.set(lesson.title),
    });

    this.lessonService.getLessonNotes(this.lessonId).subscribe({
      next: (notes) => {
        notes.forEach((n) => this.notesArray.push(this.createNoteGroup(n)));
      },
    });
  }

  private createNoteGroup(data?: Partial<NoteSequence>): FormGroup {
    return this.fb.group({
      note: [data?.note ?? 'C4', [Validators.required, Validators.pattern(this.notePattern)]],
      duration: [data?.duration ?? 1, Validators.required],
      is_rest: [data?.is_rest ?? false],
      is_chord: [data?.is_chord ?? false],
      chord_group: [data?.chord_group ?? null],
      velocity: [data?.velocity ?? 80, [Validators.min(1), Validators.max(127)]],
      finger: [data?.finger ?? null],
      hand: [data?.hand ?? null],
    });
  }

  addNote(): void {
    this.notesArray.push(this.createNoteGroup());
    this.selectedIndex.set(this.notesArray.length - 1);
  }

  addRest(): void {
    this.notesArray.push(this.createNoteGroup({ note: 'REST', is_rest: true }));
    this.selectedIndex.set(this.notesArray.length - 1);
  }

  addChord(): void {
    const group = (this.notesArray.length > 0
      ? Math.max(...this.notesArray.controls.map(c => c.get('chord_group')?.value ?? 0)) + 1
      : 1);
    const notes = ['C4', 'E4', 'G4'];
    notes.forEach(n => {
      this.notesArray.push(this.createNoteGroup({ note: n, is_chord: true, chord_group: group }));
    });
    this.selectedIndex.set(this.notesArray.length - 1);
  }

  removeNote(index: number): void {
    this.notesArray.removeAt(index);
    if (this.selectedIndex() >= this.notesArray.length) {
      this.selectedIndex.set(Math.max(0, this.notesArray.length - 1));
    }
  }

  duplicateNote(index: number): void {
    const original = this.notesArray.at(index) as FormGroup;
    const clone = this.createNoteGroup(original.value);
    this.notesArray.insert(index + 1, clone);
    this.selectedIndex.set(index + 1);
  }

  onRestChange(index: number): void {
    const group = this.getGroup(index);
    if (group.get('is_rest')?.value) {
      group.patchValue({ note: 'REST' });
    } else {
      group.patchValue({ note: 'C4' });
    }
  }

  clearAll(): void {
    if (confirm('¿Eliminar todas las notas?')) {
      this.notesArray.clear();
      this.selectedIndex.set(0);
    }
  }

  onDrop(event: CdkDragDrop<string[]>): void {
    moveItemInArray(this.notesArray.controls, event.previousIndex, event.currentIndex);
    this.selectedIndex.set(event.currentIndex);
  }

  getGroup(i: number): FormGroup {
    return this.notesArray.at(i) as FormGroup;
  }

  saveNotes(): void {
    this.saving.set(true);
    const notes: NoteSequenceCreate[] = this.notesArray.controls.map((ctrl, idx) => ({
      ...ctrl.value,
      sequence_order: idx,
    }));

    this.lessonService.updateNotes(this.lessonId, notes).subscribe({
      next: () => {
        this.saving.set(false);
        this.snackBar.open('Notas guardadas correctamente', 'OK', { duration: 3000 });
      },
      error: (err: { error?: { detail?: string } }) => {
        this.saving.set(false);
        this.snackBar.open(err.error?.detail || 'Error al guardar notas', 'OK', { duration: 3000 });
      },
    });
  }

  goBack(): void {
    this.router.navigate(['/admin/lessons/list']);
  }
}
