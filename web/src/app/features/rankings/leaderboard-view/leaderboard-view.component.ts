import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';

import { RankingService } from '../../../core/services/ranking.service';

@Component({
  selector: 'app-leaderboard-view',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="leaderboard-view">
      <h2>Leaderboard</h2>

      <!-- Tabs -->
      <div class="tabs">
        <button class="tab" [class.active]="activeTab === 0" (click)="switchTab(0)">Global</button>
        <button class="tab" [class.active]="activeTab === 1" (click)="switchTab(1)">Semanal</button>
        <button class="tab" [class.active]="activeTab === 2" (click)="switchTab(2)">Rachas</button>
      </div>

      <!-- Global -->
      @if (activeTab === 0) {
        @if (rankingService.globalLeaderboard(); as data) {
          <p class="info">{{ data.total_participants }} participantes</p>
          <div class="table-container">
            <table class="table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Usuario</th>
                  <th>Nivel</th>
                  <th>XP Total</th>
                </tr>
              </thead>
              <tbody>
                @for (e of data.leaderboard; track e.user_id) {
                  <tr>
                    <td [class]="rankClass(e.rank)">{{ e.rank }}</td>
                    <td>{{ e.full_name }}</td>
                    <td class="level-cell">{{ e.level }}</td>
                    <td class="xp-cell">{{ e.total_xp | number }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        } @else {
          <div class="loading">Cargando...</div>
        }
      }

      <!-- Semanal -->
      @if (activeTab === 1) {
        @if (rankingService.weeklyLeaderboard(); as data) {
          <p class="info">
            {{ data.total_participants }} participantes — Resetea en {{ data.days_remaining }} días
          </p>
          <div class="table-container">
            <table class="table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Usuario</th>
                  <th>XP Semanal</th>
                </tr>
              </thead>
              <tbody>
                @for (e of data.leaderboard; track e.user_id) {
                  <tr>
                    <td [class]="rankClass(e.rank)">{{ e.rank }}</td>
                    <td>{{ e.full_name }}</td>
                    <td class="xp-cell">{{ e.weekly_xp | number }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        } @else {
          <div class="loading">Cargando...</div>
        }
      }

      <!-- Rachas -->
      @if (activeTab === 2) {
        @if (rankingService.streakLeaderboard(); as data) {
          <p class="info">{{ data.total_participants }} participantes</p>
          <div class="table-container">
            <table class="table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Usuario</th>
                  <th>Racha actual</th>
                  <th>Mejor racha</th>
                </tr>
              </thead>
              <tbody>
                @for (e of data.leaderboard; track e.user_id) {
                  <tr>
                    <td [class]="rankClass(e.rank)">{{ e.rank }}</td>
                    <td>{{ e.full_name }}</td>
                    <td class="streak-cell">🔥 {{ e.current_streak }} días</td>
                    <td>{{ e.longest_streak }} días</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        } @else {
          <div class="loading">Cargando...</div>
        }
      }
    </div>
  `,
  styles: [`
    .leaderboard-view { }
    h2 { color: var(--color-primary); margin-bottom: 16px; font-size: 22px; }
    .info { color: var(--text-muted); margin: 12px 0; font-size: 14px; }
    .rank-gold { color: #ffd700; font-weight: bold; }
    .rank-silver { color: #c0c0c0; font-weight: bold; }
    .rank-bronze { color: #cd7f32; font-weight: bold; }
    .xp-cell { color: var(--color-primary); font-weight: bold; }
    .level-cell { color: var(--color-violet); font-weight: bold; }
    .streak-cell { color: var(--color-warning); font-weight: bold; }
    .loading { text-align: center; color: var(--text-dimmed); padding: 48px; }
  `],
})
export class LeaderboardViewComponent implements OnInit {
  readonly rankingService = inject(RankingService);
  activeTab = 0;

  ngOnInit(): void {
    this.rankingService.loadGlobalLeaderboard().subscribe();
  }

  switchTab(index: number): void {
    this.activeTab = index;
    switch (index) {
      case 0: this.rankingService.loadGlobalLeaderboard().subscribe(); break;
      case 1: this.rankingService.loadWeeklyLeaderboard().subscribe(); break;
      case 2: this.rankingService.loadStreakLeaderboard().subscribe(); break;
    }
  }

  rankClass(rank: number): string {
    if (rank === 1) return 'rank-gold';
    if (rank === 2) return 'rank-silver';
    if (rank === 3) return 'rank-bronze';
    return '';
  }
}
