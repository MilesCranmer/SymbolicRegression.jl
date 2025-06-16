import { AbstractAudioRenderer } from './abstract_audio_renderer.js';
import * as AudioUtil from './audio_util.js';
import { AuditoryDescription } from './auditory_description.js';
export declare class PunctuationRenderer extends AbstractAudioRenderer {
    private static PAUSE_PUNCTUATION;
    markup(descrs: AuditoryDescription[]): string;
    pause(pause: AudioUtil.PauseValue): string;
}
