/**
 * Modelos de datos para el Catálogo Oficial de Digitaciones Andinas (HU-05, SUB-05-B).
 */

export type AndeanInstrumentType = 'quena' | 'zampona' | 'tarka';

export interface Fingering {
  id: string;
  instrument: AndeanInstrumentType;
  note: string;
  octave: number;
  holes_covered: number[];
  is_alternate: boolean;
  description?: string | null;
  created_at: string;
}

export interface FingeringCreate {
  instrument: AndeanInstrumentType;
  note: string;
  octave: number;
  holes_covered: number[];
  is_alternate: boolean;
  description?: string;
}
