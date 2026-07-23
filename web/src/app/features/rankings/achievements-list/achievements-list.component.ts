import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatDialog } from '@angular/material/dialog';
import {
  LucidePlus,
  LucidePencil,
  LucideTrash2,
  LucideCheckCircle,
  LucideXCircle,
} from '@lucide/angular';

import { RankingService } from '../../../core/services/ranking.service';
import { Achievement } from '../../../core/models/ranking.model';
import { AchievementFormDialogComponent } from '../achievement-form-dialog/achievement-form-dialog.component';

@Component({
  selector: 'app-achievements-list',
  standalone: true,
  imports: [
    CommonModule,
    LucidePlus, LucidePencil, LucideTrash2, LucideCheckCircle, LucideXCircle,
  ],
  template: `
    <div class="achievements-list">
      <div class="header">
        <h2>Logros del sistema</h2>
        <button class="btn btn-primary" (click)="openCreateDialog()">
          <svg lucidePlus [size]="16"></svg> Nuevo logro
        </button>
      </div>

      <div class="table-container">
        <table class="table">
          <thead>
            <tr>
              <th>Ícono</th>
              <th>Nombre</th>
              <th>Código</th>
              <th>Categoría</th>
              <th>Rareza</th>
              <th>XP</th>
              <th>Requisito</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            @for (a of rankingService.achievements(); track a.id) {
              <tr>
                <td>{{ a.icon }}</td>
                <td>{{ a.name }}</td>
                <td class="code-cell">{{ a.code }}</td>
                <td><span class="chip" [class]="'chip-' + a.category">{{ categoryLabel(a.category) }}</span></td>
                <td><span class="rarity" [class]="'rarity-' + a.rarity">{{ rarityLabel(a.rarity) }}</span></td>
                <td class="xp-cell">+{{ a.xp_reward }}</td>
                <td>{{ reqTypeLabel(a.requirement_type) }} ≥ {{ a.requirement_value }}</td>
                <td>
                  @if (a.is_active) {
                    <svg lucideCheckCircle [size]="18" class="active-icon"></svg>
                  } @else {
                    <svg lucideXCircle [size]="18" class="inactive-icon"></svg>
                  }
                </td>
                <td>
                  <div class="action-buttons">
                    <button class="btn-icon" title="Editar" (click)="openEditDialog(a)">
                      <svg lucidePencil [size]="16"></svg>
                    </button>
                    <button class="btn-icon danger" title="Eliminar" (click)="deleteAchievement(a)">
                      <svg lucideTrash2 [size]="16"></svg>
                    </button>
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
  styles: [`
    .achievements-list { }
    .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    h2 { color: var(--color-primary); margin: 0; font-size: 22px; }
    .code-cell { font-family: monospace; color: var(--color-primary); }
    .xp-cell { color: var(--color-success); font-weight: bold; }

    .chip-practice { background: #1e3a5f; color: #60a5fa; }
    .chip-streak { background: #3b2a0a; color: #f59e0b; }
    .chip-score { background: #0a2e1f; color: #34d399; }
    .chip-social { background: #2e1065; color: #a78bfa; }
    .chip-milestone { background: #1a1a2e; color: var(--text-secondary); }

    .rarity { font-size: 12px; font-weight: 600; }
    .rarity-common { color: var(--text-muted); }
    .rarity-rare { color: var(--color-blue); }
    .rarity-epic { color: var(--color-violet); }
    .rarity-legendary { color: var(--color-warning); }

    .active-icon { color: var(--color-success); }
    .inactive-icon { color: var(--text-dimmed); }

    .action-buttons { display: flex; gap: 2px; }
  `],
})
export class AchievementsListComponent implements OnInit {
  readonly rankingService = inject(RankingService);
  private readonly dialog = inject(MatDialog);

  private readonly categoryLabels: Record<string, string> = {
    practice: 'Práctica', streak: 'Racha', score: 'Puntuación', social: 'Social', milestone: 'Hito',
  };
  private readonly rarityLabels: Record<string, string> = {
    common: 'Común', rare: 'Raro', epic: 'Épico', legendary: 'Legendario',
  };
  private readonly reqTypeLabels: Record<string, string> = {
    count: 'Cantidad', streak: 'Racha', score: 'Puntuación', special: 'Especial',
  };

  categoryLabel(key: string): string { return this.categoryLabels[key] ?? key; }
  rarityLabel(key: string): string { return this.rarityLabels[key] ?? key; }
  reqTypeLabel(key: string): string { return this.reqTypeLabels[key] ?? key; }

  ngOnInit(): void {
    this.rankingService.loadAchievements().subscribe();
  }

  openCreateDialog(): void {
    const ref = this.dialog.open(AchievementFormDialogComponent, {
      width: '500px',
      data: null,
    });
    ref.afterClosed().subscribe((result) => {
      if (result) {
        this.rankingService.createAchievement(result).subscribe(() => {
          this.rankingService.loadAchievements().subscribe();
        });
      }
    });
  }

  openEditDialog(achievement: Achievement): void {
    const ref = this.dialog.open(AchievementFormDialogComponent, {
      width: '500px',
      data: achievement,
    });
    ref.afterClosed().subscribe((result) => {
      if (result) {
        this.rankingService.updateAchievement(achievement.id, result).subscribe(() => {
          this.rankingService.loadAchievements().subscribe();
        });
      }
    });
  }

  deleteAchievement(achievement: Achievement): void {
    if (confirm('¿Eliminar logro "' + achievement.name + '"?')) {
      this.rankingService.deleteAchievement(achievement.id).subscribe(() => {
        this.rankingService.loadAchievements().subscribe();
      });
    }
  }
}
