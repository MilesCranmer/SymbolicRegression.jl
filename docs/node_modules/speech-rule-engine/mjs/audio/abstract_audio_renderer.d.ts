import { KeyCode } from '../common/event_util.js';
import { AudioRenderer } from './audio_renderer.js';
import { AuditoryDescription } from './auditory_description.js';
import { Span } from './span.js';
export declare abstract class AbstractAudioRenderer implements AudioRenderer {
    private separator_;
    abstract markup(descrs: AuditoryDescription[]): string;
    set separator(sep: string);
    get separator(): string;
    error(_key: KeyCode | string): string | null;
    merge(spans: Span[]): string;
    finalize(str: string): string;
    pauseValue(value: string): number;
}
