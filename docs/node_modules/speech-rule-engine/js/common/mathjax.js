"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const engine_js_1 = require("./engine.js");
const EngineConst = require("../common/engine_const.js");
const System = require("./system.js");
(function () {
    const SIGNAL = MathJax.Callback.Signal('Sre');
    MathJax.Extension.Sre = {
        version: System.version,
        signal: SIGNAL,
        ConfigSre: function () {
            engine_js_1.EnginePromise.getall().then(() => MathJax.Callback.Queue(MathJax.Hub.Register.StartupHook('mml Jax Ready', {}), ['Post', MathJax.Hub.Startup.signal, 'Sre Ready']));
        }
    };
    System.setupEngine({
        mode: EngineConst.Mode.HTTP,
        json: MathJax.Ajax.config.path['SRE'] + '/mathmaps',
        xpath: MathJax.Ajax.config.path['SRE'] + '/wgxpath.install.js',
        semantics: true
    });
    MathJax.Extension.Sre.ConfigSre();
})();
