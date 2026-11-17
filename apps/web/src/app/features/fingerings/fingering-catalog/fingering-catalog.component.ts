import { Component, inject, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatSnackBar } from '@angular/material/snack-bar';
import {
  LucidePlus,
  LucideTrash2,
  LucideMusic,
  LucideAlertCircle,
  LucideSliders,
} from '@lucide/angular';

import { FingeringAdminService } from '../../../core/services/fingering-admin.service';
import { FingeringCreate, AndeanInstrumentType } from '../../../core/models/fingering.model';

export interface NoteOption {
  symbol: string;
  name: string;
}

@Component({
  selector: 'app-fingering-catalog',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    LucidePlus,
    LucideTrash2,
    LucideMusic,
    LucideAlertCircle,
    LucideSliders,
  ],
  template: `
    <div class="fingering-page">
      <!-- Header -->
      <div class="page-header">
        <div class="header-titles">
          <h1 class="page-title">Catálogo y Editor Oficial de Digitaciones</h1>
          <p class="page-subtitle">
            Gestión y edición gráfica interactiva de posiciones y digitaciones para Quena, Zampoña y
            Tarka.
          </p>
        </div>
      </div>

      <div class="catalog-grid">
        <!-- Editor Column (Left) -->
        <div class="editor-column card">
          <div class="card-header">
            <h2 class="card-title">
              <svg lucideSliders [size]="20" class="card-icon"></svg>
              Editor Gráfico de Digitación
            </h2>
          </div>

          <form (ngSubmit)="saveFingering()" class="editor-form">
            <!-- Instrument Tabs -->
            <div class="form-group">
              <span class="form-label">Instrumento Andino</span>
              <div class="instrument-selector">
                <button
                  type="button"
                  class="instrument-tab"
                  [class.active]="selectedInstrument() === 'quena'"
                  (click)="onSelectInstrument('quena')"
                >
                  Quena (7 orificios)
                </button>
                <button
                  type="button"
                  class="instrument-tab"
                  [class.active]="selectedInstrument() === 'tarka'"
                  (click)="onSelectInstrument('tarka')"
                >
                  Tarka (6 orificios)
                </button>
                <button
                  type="button"
                  class="instrument-tab"
                  [class.active]="selectedInstrument() === 'zampona'"
                  (click)="onSelectInstrument('zampona')"
                >
                  Zampoña (13 tubos)
                </button>
              </div>
            </div>

            <!-- Note & Octave Row -->
            <div class="form-row">
              <div class="form-group flex-1">
                <label for="note-select" class="form-label">Nota Musical</label>
                <select
                  id="note-select"
                  class="form-control"
                  [ngModel]="selectedNote()"
                  (ngModelChange)="selectedNote.set($event)"
                  name="note"
                >
                  @for (n of availableNotes; track n.symbol) {
                    <option [value]="n.symbol">{{ n.name }} ({{ n.symbol }})</option>
                  }
                </select>
              </div>

              <div class="form-group flex-1">
                <label for="octave-select" class="form-label">Octava</label>
                <select
                  id="octave-select"
                  class="form-control"
                  [ngModel]="selectedOctave()"
                  (ngModelChange)="selectedOctave.set(+$event)"
                  name="octave"
                >
                  @for (oct of availableOctaves; track oct) {
                    <option [value]="oct">Octava {{ oct }}</option>
                  }
                </select>
              </div>
            </div>

            <!-- Scientific Notation Preview & Alternate Checkbox -->
            <div class="preview-bar">
              <div class="scientific-note">
                <span class="preview-label">Notación:</span>
                <span class="preview-badge">{{ currentScientificNote() }}</span>
              </div>
              <label class="checkbox-label">
                <input
                  type="checkbox"
                  [checked]="isAlternate()"
                  (change)="isAlternate.set($any($event.target).checked)"
                />
                <span>Digitación Alternativa</span>
              </label>
            </div>

            <!-- Graphical Instrument Canvas / Schematic -->
            <div class="schematic-container">
              <div class="schematic-header">
                <span class="schematic-title"
                  >Esquema Gráfico (Clic para alternar orificio/tubo)</span
                >
                <button type="button" class="btn-link" (click)="resetHoles()">Limpiar</button>
              </div>

              <!-- QUENA GRAPHICAL VIEW -->
              @if (selectedInstrument() === 'quena') {
                <div class="quena-schematic">
                  <div class="thumb-section">
                    <span class="hole-label">Pulgar posterior</span>
                    <button
                      type="button"
                      class="hole-btn thumb-hole"
                      [class.covered]="holesCovered()[0] === 1"
                      (click)="toggleHole(0)"
                      [attr.aria-label]="
                        'Orificio pulgar ' + (holesCovered()[0] === 1 ? 'tapado' : 'abierto')
                      "
                    >
                      <span class="hole-inner"></span>
                    </button>
                  </div>

                  <div class="quena-body">
                    <div class="instrument-embouchure" title="Bisel / Embocadura"></div>
                    <div class="front-holes-column">
                      @for (holeIndex of [1, 2, 3, 4, 5, 6]; track holeIndex) {
                        <div class="hole-row">
                          <span class="hole-number">{{ holeIndex }}</span>
                          <button
                            type="button"
                            class="hole-btn front-hole"
                            [class.covered]="holesCovered()[holeIndex] === 1"
                            (click)="toggleHole(holeIndex)"
                            [attr.aria-label]="
                              'Orificio frontal ' +
                              holeIndex +
                              ' ' +
                              (holesCovered()[holeIndex] === 1 ? 'tapado' : 'abierto')
                            "
                          >
                            <span class="hole-inner"></span>
                          </button>
                        </div>
                      }
                    </div>
                  </div>
                </div>
              }

              <!-- TARKA GRAPHICAL VIEW -->
              @if (selectedInstrument() === 'tarka') {
                <div class="tarka-schematic">
                  <div class="tarka-body">
                    <div class="tarka-mouthpiece" title="Boquilla Tarka"></div>
                    <div class="tarka-holes-column">
                      @for (holeIndex of [0, 1, 2, 3, 4, 5]; track holeIndex) {
                        <div class="hole-row">
                          <span class="hole-number">{{ holeIndex + 1 }}</span>
                          <button
                            type="button"
                            class="hole-btn tarka-hole"
                            [class.covered]="holesCovered()[holeIndex] === 1"
                            (click)="toggleHole(holeIndex)"
                            [attr.aria-label]="'Orificio tarka ' + (holeIndex + 1)"
                          >
                            <span class="hole-inner"></span>
                          </button>
                        </div>
                      }
                    </div>
                  </div>
                </div>
              }

              <!-- ZAMPOÑA GRAPHICAL VIEW -->
              @if (selectedInstrument() === 'zampona') {
                <div class="zampona-schematic">
                  <!-- Row Ira (6 tubos) -->
                  <div class="zampona-row">
                    <span class="row-tag">Fila Ira (6 tubos)</span>
                    <div class="pipes-container">
                      @for (pipeIdx of [0, 1, 2, 3, 4, 5]; track pipeIdx) {
                        <button
                          type="button"
                          class="pipe-btn"
                          [style.height.px]="140 - pipeIdx * 14"
                          [class.active-pipe]="holesCovered()[pipeIdx] === 1"
                          (click)="toggleHole(pipeIdx)"
                          [title]="'Tubo Ira ' + (pipeIdx + 1)"
                        >
                          <span class="pipe-label">I{{ pipeIdx + 1 }}</span>
                        </button>
                      }
                    </div>
                  </div>

                  <!-- Row Arca (7 tubos) -->
                  <div class="zampona-row">
                    <span class="row-tag">Fila Arca (7 tubos)</span>
                    <div class="pipes-container">
                      @for (pipeIdx of [6, 7, 8, 9, 10, 11, 12]; track pipeIdx) {
                        <button
                          type="button"
                          class="pipe-btn arca-pipe"
                          [style.height.px]="145 - (pipeIdx - 6) * 13"
                          [class.active-pipe]="holesCovered()[pipeIdx] === 1"
                          (click)="toggleHole(pipeIdx)"
                          [title]="'Tubo Arca ' + (pipeIdx - 5)"
                        >
                          <span class="pipe-label">A{{ pipeIdx - 5 }}</span>
                        </button>
                      }
                    </div>
                  </div>
                </div>
              }

              <div class="schematic-legend">
                <span class="legend-item">
                  <span class="legend-dot covered"></span> Cubierto / Activo (1)
                </span>
                <span class="legend-item">
                  <span class="legend-dot open"></span> Destapado / Inactivo (0)
                </span>
              </div>
            </div>

            <!-- Optional Description -->
            <div class="form-group">
              <label for="desc-input" class="form-label">Descripción o Indicación Técnica</label>
              <input
                id="desc-input"
                type="text"
                class="form-control"
                placeholder="Ej. Medio orificio descubierto para segunda octava"
                [ngModel]="description()"
                (ngModelChange)="description.set($event)"
                name="description"
              />
            </div>

            <!-- Submit Button -->
            <div class="form-actions">
              <button
                type="submit"
                class="btn-primary"
                [disabled]="isSaving() || !hasAnyHoleConfigured()"
              >
                <svg lucidePlus [size]="18"></svg>
                <span>{{ isSaving() ? 'Guardando...' : 'Registrar Digitación' }}</span>
              </button>
            </div>
          </form>
        </div>

        <!-- Catalog Column (Right) -->
        <div class="catalog-column card">
          <div class="card-header space-between">
            <h2 class="card-title">
              <svg lucideMusic [size]="20" class="card-icon"></svg>
              Catálogo de Digitaciones
            </h2>

            <!-- Filter Tabs -->
            <div class="filter-group">
              <button
                type="button"
                class="filter-chip"
                [class.active]="filterInstrument() === 'all'"
                (click)="setFilter('all')"
              >
                Todos
              </button>
              <button
                type="button"
                class="filter-chip"
                [class.active]="filterInstrument() === 'quena'"
                (click)="setFilter('quena')"
              >
                Quena
              </button>
              <button
                type="button"
                class="filter-chip"
                [class.active]="filterInstrument() === 'zampona'"
                (click)="setFilter('zampona')"
              >
                Zampoña
              </button>
              <button
                type="button"
                class="filter-chip"
                [class.active]="filterInstrument() === 'tarka'"
                (click)="setFilter('tarka')"
              >
                Tarka
              </button>
            </div>
          </div>

          <!-- Loading state -->
          @if (fingeringService.isLoading()) {
            <div class="loading-state">
              <p>Cargando digitaciones oficiales...</p>
            </div>
          } @else if (fingeringService.fingerings().length === 0) {
            <div class="empty-state">
              <svg lucideAlertCircle [size]="32" class="empty-icon"></svg>
              <h3>No hay digitaciones registradas</h3>
              <p>
                Utilice el editor gráfico para registrar la primera digitación de este instrumento.
              </p>
            </div>
          } @else {
            <div class="fingering-list">
              @for (fingering of fingeringService.fingerings(); track fingering.id) {
                <div class="fingering-card">
                  <div class="fingering-card-header">
                    <div class="note-badge-group">
                      <span class="note-title">{{ fingering.note }}{{ fingering.octave }}</span>
                      <span class="instrument-tag">{{ fingering.instrument | uppercase }}</span>
                    </div>

                    <div class="card-badges">
                      @if (fingering.is_alternate) {
                        <span class="badge badge-warning">Alternativa</span>
                      } @else {
                        <span class="badge badge-primary">Principal</span>
                      }

                      <button
                        type="button"
                        class="delete-btn"
                        (click)="deleteFingering(fingering.id)"
                        title="Eliminar digitación"
                        [attr.aria-label]="
                          'Eliminar digitación ' + fingering.note + fingering.octave
                        "
                      >
                        <svg lucideTrash2 [size]="16"></svg>
                      </button>
                    </div>
                  </div>

                  <!-- Holes Visual Summary -->
                  <div class="holes-summary">
                    <span class="summary-label">Orificios:</span>
                    <div class="mini-holes-row">
                      @for (h of fingering.holes_covered; track $index) {
                        <span
                          class="mini-hole"
                          [class.covered]="h === 1"
                          [title]="
                            'Orificio ' + ($index + 1) + ': ' + (h === 1 ? 'Cubierto' : 'Destapado')
                          "
                        ></span>
                      }
                    </div>
                  </div>

                  @if (fingering.description) {
                    <p class="fingering-desc">{{ fingering.description }}</p>
                  }
                </div>
              }
            </div>
          }
        </div>
      </div>
    </div>
  `,
  styles: [
    `
      .fingering-page {
        display: flex;
        flex-direction: column;
        gap: 24px;
        padding-bottom: 40px;
      }
      .page-header {
        margin-bottom: 8px;
      }
      .page-title {
        font-size: 24px;
        font-weight: 700;
        color: var(--text-primary);
        margin: 0 0 6px 0;
      }
      .page-subtitle {
        font-size: 14px;
        color: var(--text-secondary);
        margin: 0;
      }
      .catalog-grid {
        display: grid;
        grid-template-columns: 460px 1fr;
        gap: 24px;
        align-items: start;
      }
      @media (max-width: 1024px) {
        .catalog-grid {
          grid-template-columns: 1fr;
        }
      }
      .card {
        background: var(--bg-surface);
        border: 1px solid var(--border-color);
        border-radius: var(--radius-lg, 12px);
        padding: 24px;
      }
      .card-header {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 20px;
        padding-bottom: 12px;
        border-bottom: 1px solid var(--border-color);
      }
      .card-header.space-between {
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 16px;
      }
      .card-title {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 16px;
        font-weight: 600;
        color: var(--text-primary);
        margin: 0;
      }
      .card-icon {
        color: var(--color-primary);
      }
      .editor-form,
      .form-group {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }
      .form-group {
        gap: 6px;
      }
      .form-row {
        display: flex;
        gap: 16px;
      }
      .flex-1 {
        flex: 1;
      }
      .form-label {
        font-size: 13px;
        font-weight: 600;
        color: var(--text-secondary);
      }
      .form-control {
        background: var(--bg-surface-alt);
        border: 1px solid var(--border-color);
        border-radius: var(--radius-md, 8px);
        padding: 10px 14px;
        color: var(--text-primary);
        font-size: 14px;
        outline: none;
      }
      .form-control:focus {
        border-color: var(--color-primary);
      }
      .instrument-selector {
        display: flex;
        gap: 8px;
        background: var(--bg-surface-alt);
        padding: 4px;
        border-radius: var(--radius-md, 8px);
      }
      .instrument-tab {
        flex: 1;
        background: transparent;
        border: none;
        padding: 8px 10px;
        font-size: 12px;
        font-weight: 600;
        color: var(--text-secondary);
        border-radius: 6px;
        cursor: pointer;
      }
      .instrument-tab.active {
        background: var(--color-primary);
        color: #fff;
      }
      .preview-bar {
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: var(--bg-surface-alt);
        padding: 10px 14px;
        border-radius: var(--radius-md, 8px);
        border: 1px solid var(--border-color);
      }
      .scientific-note {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .preview-label {
        font-size: 13px;
        color: var(--text-secondary);
      }
      .preview-badge {
        font-size: 15px;
        font-weight: 700;
        color: var(--color-primary);
      }
      .checkbox-label {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 13px;
        color: var(--text-secondary);
        cursor: pointer;
      }
      .schematic-container {
        background: var(--bg-surface-alt);
        border: 1px solid var(--border-color);
        border-radius: var(--radius-md, 8px);
        padding: 16px;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 16px;
      }
      .schematic-header {
        width: 100%;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .schematic-title {
        font-size: 12px;
        font-weight: 600;
        color: var(--text-secondary);
      }
      .btn-link {
        background: none;
        border: none;
        color: var(--color-primary);
        font-size: 12px;
        cursor: pointer;
        text-decoration: underline;
      }
      .quena-schematic {
        display: flex;
        gap: 24px;
        align-items: center;
      }
      .thumb-section {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
      }
      .hole-label {
        font-size: 11px;
        color: var(--text-secondary);
      }
      .quena-body,
      .tarka-body {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 12px 0 20px 0;
        box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.4);
      }
      .quena-body {
        width: 60px;
        background: linear-gradient(180deg, #b45309 0%, #78350f 100%);
        border-radius: 12px;
      }
      .tarka-body {
        width: 64px;
        background: linear-gradient(180deg, #9a3412 0%, #431407 100%);
        border-radius: 6px;
      }
      .instrument-embouchure {
        width: 24px;
        height: 12px;
        background: #451a03;
        border-radius: 0 0 8px 8px;
        margin-bottom: 16px;
      }
      .tarka-mouthpiece {
        width: 32px;
        height: 14px;
        background: #270e05;
        border-radius: 4px 4px 0 0;
        margin-bottom: 16px;
      }
      .front-holes-column,
      .tarka-holes-column {
        display: flex;
        flex-direction: column;
        gap: 10px;
        align-items: center;
      }
      .hole-row {
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .hole-number {
        font-size: 10px;
        font-weight: 700;
        color: #fef08a;
        width: 12px;
        text-align: right;
      }
      .hole-btn {
        width: 28px;
        height: 28px;
        border-radius: 50%;
        background: #fff;
        border: 3px solid #1e293b;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 0;
      }
      .hole-btn.covered {
        background: #0f172a;
        border-color: var(--color-primary);
      }
      .hole-inner {
        width: 14px;
        height: 14px;
        border-radius: 50%;
        background: transparent;
      }
      .hole-btn.covered .hole-inner {
        background: var(--color-primary);
      }
      .zampona-schematic {
        display: flex;
        flex-direction: column;
        gap: 16px;
        width: 100%;
      }
      .zampona-row {
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      .row-tag {
        font-size: 12px;
        font-weight: 600;
        color: var(--color-primary);
      }
      .pipes-container {
        display: flex;
        gap: 6px;
        align-items: flex-end;
        background: rgba(0, 0, 0, 0.2);
        padding: 12px;
        border-radius: 8px;
        min-height: 160px;
      }
      .pipe-btn {
        flex: 1;
        width: 24px;
        background: linear-gradient(180deg, #d97706 0%, #b45309 100%);
        border: 2px solid transparent;
        border-radius: 4px 4px 2px 2px;
        cursor: pointer;
        display: flex;
        align-items: flex-end;
        justify-content: center;
        padding-bottom: 6px;
      }
      .pipe-btn.active-pipe {
        border-color: var(--color-primary);
        box-shadow: 0 0 10px rgba(6, 182, 212, 0.6);
        background: linear-gradient(180deg, #06b6d4 0%, #0e7490 100%);
      }
      .pipe-label {
        font-size: 10px;
        font-weight: 700;
        color: #fff;
      }
      .schematic-legend {
        display: flex;
        gap: 16px;
        font-size: 11px;
        color: var(--text-secondary);
      }
      .legend-item {
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .legend-dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
      }
      .legend-dot.covered {
        background: var(--color-primary);
      }
      .legend-dot.open {
        background: #fff;
        border: 1px solid #64748b;
      }
      .form-actions {
        margin-top: 8px;
      }
      .btn-primary {
        width: 100%;
        background: var(--color-primary);
        color: #fff;
        border: none;
        border-radius: var(--radius-md, 8px);
        padding: 12px 16px;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
      }
      .btn-primary:hover:not(:disabled) {
        background: var(--color-primary-hover);
      }
      .btn-primary:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }
      .filter-group {
        display: flex;
        gap: 6px;
      }
      .filter-chip {
        background: var(--bg-surface-alt);
        border: 1px solid var(--border-color);
        color: var(--text-secondary);
        border-radius: 16px;
        padding: 4px 12px;
        font-size: 12px;
        font-weight: 500;
        cursor: pointer;
      }
      .filter-chip.active {
        background: var(--color-primary);
        color: #fff;
        border-color: var(--color-primary);
      }
      .fingering-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
        max-height: 700px;
        overflow-y: auto;
      }
      .fingering-card {
        background: var(--bg-surface-alt);
        border: 1px solid var(--border-color);
        border-radius: var(--radius-md, 8px);
        padding: 14px 18px;
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      .fingering-card-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .note-badge-group {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .note-title {
        font-size: 18px;
        font-weight: 700;
        color: var(--text-primary);
      }
      .instrument-tag {
        font-size: 11px;
        font-weight: 600;
        background: rgba(6, 182, 212, 0.15);
        color: var(--color-primary);
        padding: 2px 8px;
        border-radius: 4px;
      }
      .card-badges {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .badge {
        font-size: 11px;
        font-weight: 600;
        padding: 2px 8px;
        border-radius: 4px;
      }
      .badge-primary {
        background: rgba(16, 185, 129, 0.2);
        color: #10b981;
      }
      .badge-warning {
        background: rgba(245, 158, 11, 0.2);
        color: #f59e0b;
      }
      .delete-btn {
        background: transparent;
        border: none;
        color: var(--text-secondary);
        cursor: pointer;
        padding: 4px;
        border-radius: 4px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .delete-btn:hover {
        color: #ef4444;
      }
      .holes-summary {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .summary-label {
        font-size: 12px;
        color: var(--text-secondary);
      }
      .mini-holes-row {
        display: flex;
        gap: 4px;
      }
      .mini-hole {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: #fff;
        border: 1px solid #475569;
      }
      .mini-hole.covered {
        background: var(--color-primary);
        border-color: var(--color-primary);
      }
      .fingering-desc {
        font-size: 12px;
        color: var(--text-secondary);
        margin: 0;
      }
      .empty-state,
      .loading-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
        text-align: center;
        color: var(--text-secondary);
      }
      .empty-icon {
        margin-bottom: 12px;
        color: var(--text-secondary);
      }
    `,
  ],
})
export class FingeringCatalogComponent implements OnInit {
  readonly fingeringService = inject(FingeringAdminService);
  private readonly snackBar = inject(MatSnackBar);

  // Form Signals
  readonly selectedInstrument = signal<AndeanInstrumentType>('quena');
  readonly selectedNote = signal<string>('G');
  readonly selectedOctave = signal<number>(4);
  readonly isAlternate = signal<boolean>(false);
  readonly description = signal<string>('');
  readonly isSaving = signal<boolean>(false);

  // Array representing covered holes (1=covered, 0=open)
  readonly holesCovered = signal<number[]>([1, 1, 1, 1, 1, 1, 1]);

  // Catalog Filter
  readonly filterInstrument = signal<string>('all');

  // Available notes for Andean instruments
  readonly availableNotes: NoteOption[] = [
    { symbol: 'C', name: 'Do' },
    { symbol: 'C#', name: 'Do#' },
    { symbol: 'D', name: 'Re' },
    { symbol: 'D#', name: 'Re#' },
    { symbol: 'E', name: 'Mi' },
    { symbol: 'F', name: 'Fa' },
    { symbol: 'F#', name: 'Fa#' },
    { symbol: 'G', name: 'Sol' },
    { symbol: 'G#', name: 'Sol#' },
    { symbol: 'A', name: 'La' },
    { symbol: 'A#', name: 'La#' },
    { symbol: 'B', name: 'Si' },
  ];

  readonly availableOctaves: number[] = [4, 5, 6];

  readonly currentScientificNote = computed(() => {
    return `${this.selectedNote()}${this.selectedOctave()}`;
  });

  readonly hasAnyHoleConfigured = computed(() => {
    return this.holesCovered().length > 0;
  });

  ngOnInit(): void {
    this.loadCatalog();
  }

  onSelectInstrument(instrument: AndeanInstrumentType): void {
    this.selectedInstrument.set(instrument);

    // Initialize holes array according to instrument anatomy
    if (instrument === 'quena') {
      // 1 thumb + 6 front = 7 holes
      this.holesCovered.set([1, 1, 1, 1, 1, 1, 1]);
      this.selectedNote.set('G');
      this.selectedOctave.set(4);
    } else if (instrument === 'tarka') {
      // 6 front holes
      this.holesCovered.set([1, 1, 1, 1, 1, 1]);
      this.selectedNote.set('C');
      this.selectedOctave.set(5);
    } else if (instrument === 'zampona') {
      // 13 tubes (6 Ira + 7 Arca)
      this.holesCovered.set(new Array(13).fill(0));
      this.selectedNote.set('G');
      this.selectedOctave.set(4);
    }
  }

  toggleHole(index: number): void {
    this.holesCovered.update((holes) => {
      const next = [...holes];
      next[index] = next[index] === 1 ? 0 : 1;
      return next;
    });
  }

  resetHoles(): void {
    this.holesCovered.update((holes) => holes.map(() => 0));
  }

  setFilter(filter: string): void {
    this.filterInstrument.set(filter);
    this.loadCatalog();
  }

  loadCatalog(): void {
    this.fingeringService.getFingerings(this.filterInstrument()).subscribe({
      error: (err) => {
        this.snackBar.open(err.message || 'Error al cargar el catálogo de digitaciones', 'Cerrar', {
          duration: 4000,
        });
      },
    });
  }

  saveFingering(): void {
    this.isSaving.set(true);

    const payload: FingeringCreate = {
      instrument: this.selectedInstrument(),
      note: this.selectedNote(),
      octave: this.selectedOctave(),
      holes_covered: this.holesCovered(),
      is_alternate: this.isAlternate(),
      description: this.description().trim() || undefined,
    };

    this.fingeringService.createFingering(payload).subscribe({
      next: () => {
        this.isSaving.set(false);
        this.snackBar.open('Digitación guardada exitosamente en el catálogo', 'Aceptar', {
          duration: 3500,
        });
        this.loadCatalog();
      },
      error: (err) => {
        this.isSaving.set(false);
        if (err.status === 409) {
          // RF-04 / S9: Digitación principal ya registrada para esta nota
          this.snackBar.open(
            err.error?.detail || 'Digitación principal ya registrada para esta nota',
            'Entendido',
            { duration: 5000 },
          );
        } else if (err.status === 401 || err.status === 403) {
          this.snackBar.open(
            'No tiene privilegios administrativos para modificar el catálogo',
            'Cerrar',
            { duration: 4000 },
          );
        } else {
          this.snackBar.open(
            err.error?.detail || err.message || 'Error al registrar digitación',
            'Cerrar',
            { duration: 4000 },
          );
        }
      },
    });
  }

  deleteFingering(id: string): void {
    if (confirm('¿Está seguro de eliminar esta digitación del catálogo oficial?')) {
      this.fingeringService.deleteFingering(id).subscribe({
        next: () => {
          this.snackBar.open('Digitación eliminada correctamente', 'Aceptar', { duration: 3000 });
        },
        error: (err) => {
          this.snackBar.open(err.message || 'Error al eliminar digitación', 'Cerrar', {
            duration: 4000,
          });
        },
      });
    }
  }
}
