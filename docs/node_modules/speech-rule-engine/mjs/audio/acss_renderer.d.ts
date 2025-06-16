import * as EngineConst from '../common/engine_const.js';
import * as AudioUtil from './audio_util.js';
import { AuditoryDescription } from './auditory_description.js';
import { MarkupRenderer } from './markup_renderer.js';
export declare class AcssRenderer extends MarkupRenderer {
    markup(descrs: AuditoryDescription[]): string;
    error(key: number): string;
    prosodyElement(key: EngineConst.personalityProps, value: number): string;
    pause(pause: AudioUtil.Pause): string;
    private prosody_;
}
