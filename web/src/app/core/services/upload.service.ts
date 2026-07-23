import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';

import { environment } from '../../../environments/environment';

/// Sube archivos a Cloud Storage via el backend.
@Injectable({ providedIn: 'root' })
export class UploadService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiBaseUrl}/uploads/media`;

  /// Sube un archivo y devuelve la URL pública.
  uploadFile(file: File, folder: 'posts' | 'avatars' | 'lessons' = 'lessons'): Observable<string> {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('folder', folder);
    return this.http.post<{ url: string }>(this.url, formData).pipe(
      map((res) => res.url),
    );
  }
}
