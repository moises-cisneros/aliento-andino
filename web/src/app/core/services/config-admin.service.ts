import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';

export interface AppConfig {
  price_monthly: number;
  price_annual: number;
  trial_days: number;
  ai_feedback_enabled: boolean;
}

export type AppConfigUpdate = Partial<AppConfig>;

@Injectable({ providedIn: 'root' })
export class ConfigAdminService {
  private readonly url = `${environment.apiBaseUrl}/admin/config`;
  private readonly http = inject(HttpClient);

  get(): Observable<AppConfig> {
    return this.http.get<AppConfig>(this.url);
  }

  update(changes: AppConfigUpdate): Observable<AppConfig> {
    return this.http.put<AppConfig>(this.url, changes);
  }
}
