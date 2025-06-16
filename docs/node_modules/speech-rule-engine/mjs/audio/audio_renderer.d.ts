import { KeyCode } from '../common/event_util.js';
import { AuditoryDescription } from './auditory_description.js';
import { Span } from './span.js';
export interface AudioRenderer {
    separator: string;
    markup(descrs: AuditoryDescription[]): string;
    error(key: KeyCode | string): string | null;
    merge(strs: Span[]): string;
    finalize(str: string): string;
}
