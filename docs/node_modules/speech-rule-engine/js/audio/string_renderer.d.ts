import { AbstractAudioRenderer } from './abstract_audio_renderer.js';
import { AuditoryDescription } from './auditory_description.js';
export declare class StringRenderer extends AbstractAudioRenderer {
    markup(descrs: AuditoryDescription[]): string;
}
export declare class CountingRenderer extends StringRenderer {
    finalize(str: string): string;
}
