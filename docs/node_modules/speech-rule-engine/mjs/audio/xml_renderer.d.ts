import * as EngineConst from '../common/engine_const.js';
import { AuditoryDescription } from './auditory_description.js';
import { MarkupRenderer } from './markup_renderer.js';
export declare abstract class XmlRenderer extends MarkupRenderer {
    abstract closeTag(tag: EngineConst.personalityProps): void;
    markup(descrs: AuditoryDescription[]): string;
}
