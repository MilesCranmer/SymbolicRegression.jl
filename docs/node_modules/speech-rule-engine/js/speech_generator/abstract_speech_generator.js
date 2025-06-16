"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AbstractSpeechGenerator = void 0;
const engine_setup_js_1 = require("../common/engine_setup.js");
const EnrichAttr = require("../enrich_mathml/enrich_attr.js");
const rebuild_stree_js_1 = require("../walker/rebuild_stree.js");
const SpeechGeneratorUtil = require("./speech_generator_util.js");
const EngineConst = require("../common/engine_const.js");
const locale_js_1 = require("../l10n/locale.js");
const clearspeak_preferences_js_1 = require("../speech_rules/clearspeak_preferences.js");
class AbstractSpeechGenerator {
    constructor() {
        this.modality = EnrichAttr.addPrefix('speech');
        this.rebuilt_ = null;
        this.options_ = {};
    }
    getRebuilt() {
        return this.rebuilt_;
    }
    setRebuilt(rebuilt) {
        this.rebuilt_ = rebuilt;
    }
    computeRebuilt(xml, force = false) {
        if (!this.rebuilt_ || force) {
            this.rebuilt_ = new rebuild_stree_js_1.RebuildStree(xml);
        }
        return this.rebuilt_;
    }
    setOptions(options) {
        this.options_ = options || {};
        this.modality = EnrichAttr.addPrefix(this.options_.modality || 'speech');
    }
    setOption(key, value) {
        const options = this.getOptions();
        options[key] = value;
        this.setOptions(options);
    }
    getOptions() {
        return this.options_;
    }
    generateSpeech(_node, xml) {
        if (!this.rebuilt_) {
            this.rebuilt_ = new rebuild_stree_js_1.RebuildStree(xml);
        }
        (0, engine_setup_js_1.setup)(this.options_);
        return SpeechGeneratorUtil.computeMarkup(this.getRebuilt().xml);
    }
    nextRules() {
        const options = this.getOptions();
        if (options.modality !== 'speech') {
            return;
        }
        const prefs = clearspeak_preferences_js_1.ClearspeakPreferences.getLocalePreferences();
        if (!prefs[options.locale]) {
            return;
        }
        EngineConst.DOMAIN_TO_STYLES[options.domain] = options.style;
        options.domain =
            options.domain === 'mathspeak' ? 'clearspeak' : 'mathspeak';
        options.style = EngineConst.DOMAIN_TO_STYLES[options.domain];
        this.setOptions(options);
    }
    nextStyle(id) {
        this.setOption('style', this.nextStyle_(this.getRebuilt().nodeDict[id]));
    }
    nextStyle_(node) {
        const { modality: modality, domain: domain, style: style } = this.getOptions();
        if (modality !== 'speech') {
            return style;
        }
        if (domain === 'mathspeak') {
            const styles = ['default', 'brief', 'sbrief'];
            const index = styles.indexOf(style);
            if (index === -1) {
                return style;
            }
            return index >= styles.length - 1 ? styles[0] : styles[index + 1];
        }
        if (domain === 'clearspeak') {
            const prefs = clearspeak_preferences_js_1.ClearspeakPreferences.getLocalePreferences();
            const loc = prefs['en'];
            if (!loc) {
                return 'default';
            }
            const smart = clearspeak_preferences_js_1.ClearspeakPreferences.relevantPreferences(node);
            const current = clearspeak_preferences_js_1.ClearspeakPreferences.findPreference(style, smart);
            const options = loc[smart].map(function (x) {
                return x.split('_')[1];
            });
            const index = options.indexOf(current);
            if (index === -1) {
                return style;
            }
            const next = index >= options.length - 1 ? options[0] : options[index + 1];
            const result = clearspeak_preferences_js_1.ClearspeakPreferences.addPreference(style, smart, next);
            return result;
        }
        return style;
    }
    getLevel(depth) {
        return locale_js_1.LOCALE.MESSAGES.navigate.LEVEL + ' ' + depth;
    }
    getActionable(actionable) {
        return actionable
            ? actionable < 0
                ? locale_js_1.LOCALE.MESSAGES.navigate.EXPANDABLE
                : locale_js_1.LOCALE.MESSAGES.navigate.COLLAPSIBLE
            : '';
    }
}
exports.AbstractSpeechGenerator = AbstractSpeechGenerator;
