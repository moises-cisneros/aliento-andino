import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';

export interface AnnouncementResult {
  segment: string;
  recipients: number;
  delivered: number;
}

@Injectable({ providedIn: 'root' })
export class AnnouncementService {
  private readonly url = `${environment.apiBaseUrl}/admin/announcements`;
  private readonly http = inject(HttpClient);

  send(title: string, body: string, segment: string): Observable<AnnouncementResult> {
    return this.http.post<AnnouncementResult>(this.url, { title, body, segment });
  }
}
