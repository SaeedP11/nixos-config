pragma Singleton

// Arithmetic for the calculator panel and the launcher's calc row. A small
// tokenizer and recursive-descent parser instead of Function()/eval, so
// letters (functions, constants, ans) are safe to accept:
//   + - * / % ^ (^ right-associative, unary minus looser than ^), brackets,
//   sqrt sin cos tan log ln abs round (radians, log base 10), pi e ans.
// "." or "," is the decimal separator. No implicit multiplication.
// History (newest first, max 50), ans and the keypad toggle persist in
// calculator.json; only valid results are saved.
import QtQuick
import Quickshell

Singleton {
    id: root

    // Last saved result, what "ans" evaluates to.
    property string ans: "0"
    property var history: []
    property bool keypad: false

    // Saves a valid expression to history and makes its result `ans`.
    // Returns the evaluation so the caller can tell whether it was saved.
    function commit(expr) {
        const e = String(expr ?? "").trim();
        const r = evaluate(e);
        if (!r.ok)
            return r;
        history = [{ expr: e, result: r.text, at: Date.now() }].concat(history).slice(0, 50);
        ans = r.text;
        save();
        return r;
    }

    function clearHistory() {
        history = [];
        save();
    }

    function setKeypad(on) {
        keypad = on;
        save();
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", String(text)]);
    }

    // Round-trips store.data so unknown fields survive a rewrite.
    function save() {
        store.save(Object.assign({}, store.data, { history, ans, keypad }));
    }

    readonly property var functions: ({
            sqrt: Math.sqrt,
            sin: Math.sin,
            cos: Math.cos,
            tan: Math.tan,
            log: Math.log10,
            ln: Math.log,
            abs: Math.abs,
            round: Math.round
        })

    // { ok, value, text }: text is the formatted value, "undefined" for a
    // division by zero or other non-finite result, "" for a syntax error.
    function evaluate(expr) {
        const tokens = tokenize(String(expr ?? ""));
        if (!tokens || tokens.length === 0)
            return { ok: false, value: NaN, text: "" };
        const p = { tokens, i: 0, divZero: false };
        let value;
        try {
            value = parseSum(p);
        } catch (e) {
            return { ok: false, value: NaN, text: "" };
        }
        if (p.i !== tokens.length)
            return { ok: false, value: NaN, text: "" };
        if (p.divZero || !isFinite(value))
            return { ok: false, value: NaN, text: "undefined" };
        return { ok: true, value, text: format(value) };
    }

    function format(v) {
        if (v === 0)
            return "0";
        const a = Math.abs(v);
        if (a >= 1e12 || a < 1e-6)
            return v.toExponential(6);
        return String(Number(v.toFixed(10)));
    }

    // Numbers, names and single-character operators; null on anything else.
    function tokenize(s) {
        const out = [];
        let i = 0;
        while (i < s.length) {
            const c = s[i];
            if (/\s/.test(c)) {
                i++;
            } else if (/[0-9.,]/.test(c)) {
                const m = /^(\d*[.,]?\d*)([eE][+-]?\d+)?/.exec(s.slice(i));
                const num = m[1];
                if (!/\d/.test(num))
                    return null;
                out.push({ t: "num", v: Number(num.replace(",", ".") + (m[2] ?? "")) });
                i += m[0].length;
            } else if (/[a-zA-Z]/.test(c)) {
                const name = /^[a-zA-Z]+/.exec(s.slice(i))[0];
                out.push({ t: "name", v: name.toLowerCase() });
                i += name.length;
            } else if ("+-*/%^()".includes(c)) {
                out.push({ t: c });
                i++;
            } else {
                return null;
            }
        }
        return out;
    }

    function peek(p) {
        return p.tokens[p.i]?.t;
    }
    function expect(p, t) {
        if (peek(p) !== t)
            throw "expected " + t;
        p.i++;
    }

    // sum := product (("+" | "-") product)*
    function parseSum(p) {
        let v = parseProduct(p);
        while (peek(p) === "+" || peek(p) === "-") {
            const op = p.tokens[p.i++].t;
            const r = parseProduct(p);
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }

    // product := unary (("*" | "/" | "%") unary)*
    function parseProduct(p) {
        let v = parseUnary(p);
        while (peek(p) === "*" || peek(p) === "/" || peek(p) === "%") {
            const op = p.tokens[p.i++].t;
            const r = parseUnary(p);
            if (op === "*") {
                v *= r;
            } else {
                if (r === 0)
                    p.divZero = true;
                v = op === "/" ? v / r : v % r;
            }
        }
        return v;
    }

    // unary := ("-" | "+") unary | power, so -2^2 is -(2^2).
    function parseUnary(p) {
        if (peek(p) === "-" || peek(p) === "+") {
            const op = p.tokens[p.i++].t;
            const v = parseUnary(p);
            return op === "-" ? -v : v;
        }
        return parsePower(p);
    }

    // power := atom ("^" unary)?, right-associative; 2^-1 is allowed.
    function parsePower(p) {
        const base = parseAtom(p);
        if (peek(p) === "^") {
            p.i++;
            return Math.pow(base, parseUnary(p));
        }
        return base;
    }

    // atom := number | constant | function "(" sum ")" | "(" sum ")"
    function parseAtom(p) {
        const tok = p.tokens[p.i];
        if (!tok)
            throw "unexpected end";
        if (tok.t === "num") {
            p.i++;
            return tok.v;
        }
        if (tok.t === "(") {
            p.i++;
            const v = parseSum(p);
            expect(p, ")");
            return v;
        }
        if (tok.t === "name") {
            p.i++;
            if (tok.v === "pi")
                return Math.PI;
            if (tok.v === "e")
                return Math.E;
            if (tok.v === "ans")
                return Number(root.ans) || 0;
            const f = root.functions[tok.v];
            if (!f)
                throw "unknown name " + tok.v;
            expect(p, "(");
            const v = parseSum(p);
            expect(p, ")");
            return f(v);
        }
        throw "unexpected " + tok.t;
    }

    StateFile {
        id: store
        name: "calculator.json"
        defaults: ({ history: [], ans: "0", keypad: false })
        onReady: {
            root.history = Array.isArray(data.history) ? data.history.slice(0, 50) : [];
            root.ans = String(data.ans ?? "0");
            root.keypad = data.keypad === true;
        }
    }
}
