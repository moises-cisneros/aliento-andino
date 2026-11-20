import { Component, computed, inject, OnInit, signal } from '@angular/core';
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
  LucideWind,
  LucideTrash2,
  LucideCopy,
  LucideGripVertical,
  LucideVolumeX,
} from '@lucide/angular';

import { LessonService } from '../../../core/services/lesson.service';
import { FingeringAdminService } from '../../../core/services/fingering-admin.service';
import {
  AndeanInstrument,
  NoteSequence,
  NoteSequenceCreate,
} from '../../../core/models/lesson.model';
import { Fingering } from '../../../core/models/fingering.model';

const FLAT_TO_SHARP: Record<string, string> = {
  Db: 'C#',
  Eb: 'D#',
  Gb: 'F#',
  Ab: 'G#',
  Bb: 'A#',
};

/** Etiquetas legibles de los instrumentos andinos aerófonos. */
const INSTRUMENT_LABELS: Record<AndeanInstrument, string> = {
  quena: 'Quena',
  zampona: 'Zampoña',
  tarka: 'Tarka',
};

@Component({
  selector: 'app-notes-editor',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    DragDropModule,
    LucideArrowLeft,
    LucideSave,
    LucidePlus,
    LucidePause,
    LucideWind,
    LucideTrash2,
    LucideCopy,
    LucideGripVertical,
    LucideVolumeX,
  ],
  template: `
    <div class="notes-editor">
      <div class="header-row">
        <div>
          <h2>Editor de Notas</h2>
          <p class="subtitle">
            {{ lessonTitle() }} — {{ instrumentLabel() }} — {{ notesArray.length }} notas
          </p>
        </div>
        <div class="header-actions">
          <button class="btn btn-ghost" (click)="goBack()">
            <svg lucideArrowLeft [size]="16"></svg> Volver
          </button>
          <button
            class="btn btn-primary"
            (click)="saveNotes()"
            [disabled]="saving() || notesArray.length === 0"
          >
            <svg lucideSave [size]="16"></svg>
            {{ saving() ? 'Guardando...' : 'Guardar Todo' }}
          </button>
        </div>
      </div>

      <!-- Barra de acciones -->
      <div class="quick-actions">
        <button class="btn" (click)="addNote()"><svg lucidePlus [size]="16"></svg> Nota</button>
        <button class="btn" (click)="addRest()">
          <svg lucidePause [size]="16"></svg> Silencio
        </button>
        <button class="btn" (click)="addBreath()" [disabled]="notesArray.length === 0">
          <svg lucideWind [size]="16"></svg> Respiración
        </button>
        <button class="btn btn-danger" (click)="clearAll()" [disabled]="notesArray.length === 0">
          <svg lucideTrash2 [size]="16"></svg> Limpiar Todo
        </button>
      </div>

      <!-- Preview visual -->
      <div class="notes-preview">
        @for (ctrl of notesArray.controls; track $index) {
          <div
            class="preview-note"
            [class.preview-rest]="ctrl.get('is_rest')?.value"
            [class.preview-breath]="ctrl.get('breath_mark')?.value"
            [class.preview-current]="$index === selectedIndex()"
            (click)="selectNote($index)"
            [title]="ctrl.get('note')?.value + ' (' + ctrl.get('duration')?.value + ')'"
          >
            {{ ctrl.get('is_rest')?.value ? '—' : ctrl.get('note')?.value }}
            @if (ctrl.get('breath_mark')?.value) {
              <span class="breath-glyph" aria-label="Marca de respiración">&#8217;</span>
            }
          </div>
        }
      </div>

      <!-- Visor de digitación andina de la nota seleccionada -->
      <div class="fingering-panel" aria-live="polite">
        <span class="panel-title">Digitación — {{ instrumentLabel() }}</span>
        @if (selectedNote(); as sel) {
          <span class="panel-note">{{ sel }}</span>
          @if (selectedFingering(); as f) {
            <div class="holes-row">
              @for (h of f.holes_covered; track $index) {
                <span
                  class="hole"
                  [class.covered]="h === 1"
                  [title]="'Orificio ' + ($index + 1) + ': ' + (h === 1 ? 'Cubierto' : 'Destapado')"
                ></span>
              }
            </div>
            @if (f.description) {
              <small class="hint">{{ f.description }}</small>
            }
          } @else {
            <small class="hint">Sin digitación registrada en el catálogo para esta nota.</small>
          }
        } @else {
          <small class="hint">Selecciona una nota para ver su digitación.</small>
        }
      </div>

      <!-- Lista drag & drop -->
      <div class="notes-list" cdkDropList (cdkDropListDropped)="onDrop($event)">
        @for (ctrl of notesArray.controls; track $index; let i = $index) {
          <div
            class="note-row"
            cdkDrag
            [class.selected-row]="i === selectedIndex()"
            (click)="selectNote(i)"
          >
            <div class="drag-handle" cdkDragHandle>
              <svg lucideGripVertical [size]="16"></svg>
            </div>

            <span class="note-position">{{ i + 1 }}</span>

            <div class="note-fields" [formGroup]="getGroup(i)">
              <div class="form-group field-note">
                <input
                  class="form-input"
                  formControlName="note"
                  (input)="syncSelectedNote()"
                  [readonly]="ctrl.get('is_rest')?.value"
                  placeholder="C4"
                />
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

              <label class="checkbox">
                <input type="checkbox" formControlName="is_rest" (change)="onRestChange(i)" />
                <span>Sil</span>
              </label>
              <label class="checkbox">
                <input type="checkbox" formControlName="breath_mark" />
                <span>Resp</span>
              </label>
            </div>

            <div class="row-actions">
              <button
                class="btn-icon"
                title="Duplicar"
                (click)="duplicateNote(i); $event.stopPropagation()"
              >
                <svg lucideCopy [size]="14"></svg>
              </button>
              <button
                class="btn-icon danger"
                title="Eliminar"
                (click)="removeNote(i); $event.stopPropagation()"
              >
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
  styles: [
    `
      .notes-editor {
        max-width: 1200px;
        margin: 0 auto;
      }
      .header-row {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 16px;
      }
      .header-row h2 {
        color: var(--text-secondary);
        margin: 0;
      }
      .subtitle {
        color: var(--text-muted);
        font-size: 14px;
        margin: 4px 0 0;
      }
      .header-actions {
        display: flex;
        gap: 8px;
      }

      .quick-actions {
        display: flex;
        gap: 8px;
        margin-bottom: 16px;
        flex-wrap: wrap;
      }

      .notes-preview {
        display: flex;
        gap: 3px;
        overflow-x: auto;
        padding: 8px;
        margin-bottom: 16px;
        background: var(--bg-surface-alt);
        border-radius: 8px;
      }
      .preview-note {
        min-width: 36px;
        height: 28px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--color-primary-subtle);
        color: var(--color-primary);
        border-radius: 4px;
        font-size: 11px;
        cursor: pointer;
        user-select: none;
        padding: 0 4px;
      }
      .preview-rest {
        background: rgba(100, 116, 139, 0.15);
        color: var(--text-dimmed);
      }
      .preview-breath {
        font-weight: 600;
      }
      .breath-glyph {
        margin-left: 2px;
      }
      .fingering-panel {
        display: flex;
        align-items: center;
        gap: 12px;
        flex-wrap: wrap;
        padding: 10px 12px;
        margin-bottom: 16px;
        background: var(--bg-surface-alt);
        border-radius: 8px;
      }
      .panel-title {
        color: var(--text-muted);
        font-size: 12px;
      }
      .panel-note {
        color: var(--color-primary);
        font-weight: 600;
      }
      .holes-row {
        display: flex;
        gap: 6px;
      }
      .hole {
        width: 16px;
        height: 16px;
        border-radius: 50%;
        border: 2px solid var(--color-primary);
      }
      .hole.covered {
        background: var(--color-primary);
      }
      .hint {
        color: var(--text-muted);
        font-size: 12px;
      }
      .preview-current {
        outline: 2px solid var(--color-primary);
      }

      .note-row {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-radius: 8px;
        margin-bottom: 4px;
        cursor: pointer;
        border: 1px solid transparent;
      }
      .note-row.selected-row {
        border-color: var(--color-primary);
      }
      .drag-handle {
        cursor: grab;
        color: var(--text-dimmed);
        display: flex;
        align-items: center;
      }
      .note-position {
        color: var(--text-dimmed);
        font-size: 12px;
        min-width: 24px;
        text-align: center;
      }
      .note-fields {
        display: flex;
        align-items: center;
        gap: 6px;
        flex-wrap: wrap;
        flex: 1;
      }

      .note-fields .form-group {
        margin-bottom: 0;
      }
      .note-fields .form-input,
      .note-fields .form-select {
        padding: 6px 8px;
        font-size: 13px;
      }

      .field-note {
        width: 80px;
      }
      .field-sm {
        width: 70px;
      }
      .field-xs {
        width: 60px;
      }
      .row-actions {
        display: flex;
        gap: 2px;
      }

      .cdk-drag-preview {
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
      }
      .cdk-drag-placeholder {
        opacity: 0.3;
      }

      .empty-state {
        text-align: center;
        padding: 48px;
        color: var(--text-muted);
      }
      .empty-state p {
        margin-top: 12px;
      }

      .checkbox {
        font-size: 12px;
        gap: 4px;
      }
      .checkbox input[type='checkbox'] {
        width: 14px;
        height: 14px;
      }
    `,
  ],
})
export class NotesEditorComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly lessonService = inject(LessonService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);
  private readonly fingeringService = inject(FingeringAdminService);

  readonly lessonTitle = signal('');
  readonly instrument = signal<AndeanInstrument>('quena');
  readonly instrumentLabel = computed(() => INSTRUMENT_LABELS[this.instrument()]);
  /** Nota (p. ej. "G4") de la fila seleccionada; null si es silencio o no hay fila. */
  readonly selectedNote = signal<string | null>(null);
  readonly selectedFingering = computed(() => this.findFingering(this.selectedNote()));
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
      next: (lesson) => {
        this.lessonTitle.set(lesson.title);
        this.instrument.set(lesson.instrument ?? 'quena');
        // El error real queda expuesto en fingeringService.error().
        this.fingeringService
          .getFingerings(this.instrument())
          .subscribe({ error: () => undefined });
      },
    });

    this.lessonService.getLessonNotes(this.lessonId).subscribe({
      next: (notes) => {
        notes.forEach((n) => this.notesArray.push(this.createNoteGroup(n)));
        this.syncSelectedNote();
      },
    });
  }

  private createNoteGroup(data?: Partial<NoteSequence>): FormGroup {
    return this.fb.group({
      note: [data?.note ?? 'C4', [Validators.required, Validators.pattern(this.notePattern)]],
      duration: [data?.duration ?? 1, Validators.required],
      is_rest: [data?.is_rest ?? false],
      breath_mark: [data?.breath_mark ?? false],
    });
  }

  addNote(): void {
    this.notesArray.push(this.createNoteGroup());
    this.selectNote(this.notesArray.length - 1);
  }

  addRest(): void {
    this.notesArray.push(this.createNoteGroup({ note: 'REST', is_rest: true }));
    this.selectNote(this.notesArray.length - 1);
  }

  addBreath(): void {
    const last = this.notesArray.length - 1;
    if (last < 0) return;
    this.getGroup(last).patchValue({ breath_mark: true });
  }

  removeNote(index: number): void {
    this.notesArray.removeAt(index);
    if (this.selectedIndex() >= this.notesArray.length) {
      this.selectNote(Math.max(0, this.notesArray.length - 1));
    } else {
      this.syncSelectedNote();
    }
  }

  duplicateNote(index: number): void {
    const original = this.notesArray.at(index) as FormGroup;
    const clone = this.createNoteGroup(original.value);
    this.notesArray.insert(index + 1, clone);
    this.selectNote(index + 1);
  }

  onRestChange(index: number): void {
    const group = this.getGroup(index);
    if (group.get('is_rest')?.value) {
      group.patchValue({ note: 'REST' });
    } else {
      group.patchValue({ note: 'C4' });
    }
    this.syncSelectedNote();
  }

  clearAll(): void {
    if (confirm('¿Eliminar todas las notas?')) {
      this.notesArray.clear();
      this.selectNote(0);
    }
  }

  onDrop(event: CdkDragDrop<string[]>): void {
    moveItemInArray(this.notesArray.controls, event.previousIndex, event.currentIndex);
    this.selectNote(event.currentIndex);
  }

  selectNote(index: number): void {
    this.selectedIndex.set(index);
    this.syncSelectedNote();
  }

  /** Busca la digitación del catálogo para una nota científica (p. ej. "F#5"). */
  findFingering(note: string | null): Fingering | null {
    const match = /^([A-G][#b]?)([0-8])$/.exec(note ?? '');
    if (!match) return null;
    const symbol = FLAT_TO_SHARP[match[1]] ?? match[1];
    const octave = Number(match[2]);
    const candidates = this.fingeringService
      .fingerings()
      .filter((f) => f.note === symbol && f.octave === octave);
    return candidates.find((f) => !f.is_alternate) ?? candidates[0] ?? null;
  }

  syncSelectedNote(): void {
    const ctrl = this.notesArray.at(this.selectedIndex());
    const value = ctrl && !ctrl.get('is_rest')?.value ? (ctrl.get('note')?.value ?? null) : null;
    this.selectedNote.set(value);
  }

  getGroup(i: number): FormGroup {
    return this.notesArray.at(i) as FormGroup;
  }

  saveNotes(): void {
    this.saving.set(true);
    const notes: NoteSequenceCreate[] = this.notesArray.controls.map((ctrl, idx) => {
      const { note, duration, is_rest, breath_mark } = ctrl.value;
      return {
        position: idx,
        note,
        duration: Number(duration),
        is_rest,
        breath_mark,
        fingering_id: is_rest ? null : (this.findFingering(note)?.id ?? null),
      };
    });

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
