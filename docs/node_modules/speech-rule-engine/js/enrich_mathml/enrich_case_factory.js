"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const case_binomial_js_1 = require("./case_binomial.js");
const case_double_script_js_1 = require("./case_double_script.js");
const case_embellished_js_1 = require("./case_embellished.js");
const case_empheq_js_1 = require("./case_empheq.js");
const case_limit_js_1 = require("./case_limit.js");
const case_line_js_1 = require("./case_line.js");
const case_multiscripts_js_1 = require("./case_multiscripts.js");
const case_proof_js_1 = require("./case_proof.js");
const case_table_js_1 = require("./case_table.js");
const case_tensor_js_1 = require("./case_tensor.js");
const case_text_js_1 = require("./case_text.js");
const enrich_case_js_1 = require("./enrich_case.js");
enrich_case_js_1.factory.push(...[
    {
        test: case_limit_js_1.CaseLimit.test,
        constr: (node) => new case_limit_js_1.CaseLimit(node)
    },
    {
        test: case_embellished_js_1.CaseEmbellished.test,
        constr: (node) => new case_embellished_js_1.CaseEmbellished(node)
    },
    {
        test: case_double_script_js_1.CaseDoubleScript.test,
        constr: (node) => new case_double_script_js_1.CaseDoubleScript(node)
    },
    {
        test: case_tensor_js_1.CaseTensor.test,
        constr: (node) => new case_tensor_js_1.CaseTensor(node)
    },
    {
        test: case_multiscripts_js_1.CaseMultiscripts.test,
        constr: (node) => new case_multiscripts_js_1.CaseMultiscripts(node)
    },
    { test: case_line_js_1.CaseLine.test, constr: (node) => new case_line_js_1.CaseLine(node) },
    {
        test: case_binomial_js_1.CaseBinomial.test,
        constr: (node) => new case_binomial_js_1.CaseBinomial(node)
    },
    {
        test: case_proof_js_1.CaseProof.test,
        constr: (node) => new case_proof_js_1.CaseProof(node)
    },
    {
        test: case_empheq_js_1.CaseEmpheq.test,
        constr: (node) => new case_empheq_js_1.CaseEmpheq(node)
    },
    {
        test: case_table_js_1.CaseTable.test,
        constr: (node) => new case_table_js_1.CaseTable(node)
    },
    { test: case_text_js_1.CaseText.test, constr: (node) => new case_text_js_1.CaseText(node) }
]);
