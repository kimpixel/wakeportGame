#!/usr/bin/env node
// Übersetzungen (gettext) pflegen – ohne gettext-Tools, nur node.
//
//   node tools/i18n.js extract            Texte aus scripts/**/*.gd sammeln -> locale/messages.pot,
//                                         alle locale/*.po abgleichen (neue leer, entfallene gelöscht)
//   node tools/i18n.js stats              je Sprache: übersetzt / fehlt
//   node tools/i18n.js missing LANG [N]   fehlende Texte einer Sprache als JSON {msgid: ""} ausgeben
//   node tools/i18n.js apply LANG FILE    Übersetzungen aus JSON {msgid: msgstr} in locale/LANG.po übernehmen
//   node tools/i18n.js check              Platzhalter (%s, %d …) der Übersetzungen mit dem Original vergleichen
//
// Gesammelt wird (Ausgangstext ist Deutsch, msgid = deutscher Text):
//   - tr("…"), tr_n("…", "…", n), atr("…") mit Text-Literal als erstem Argument (auch """…""")
//   - Zeilen mit dem Kommentar `# i18n` am Ende: alle Texte der Zeile außer Schlüsseln ("x": …)
//   - zwischen `# i18n-begin [schlüssel,…]` und `# i18n-end`: alle Werte dieser Schlüssel
//     (ohne Liste bzw. `*`: alle Texte außer Schlüsseln)
// Zur Laufzeit übersetzt das Spiel mit tr() bzw. Loc.t() (siehe scripts/loc.gd).
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const LOCALE = path.join(ROOT, 'locale');
const POT = path.join(LOCALE, 'messages.pot');

function walk(dir, out) {
	for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
		const p = path.join(dir, e.name);
		if (e.isDirectory()) walk(p, out);
		else if (e.name.endsWith('.gd')) out.push(p);
	}
	return out;
}

// GDScript-Textliteral ab Position i lesen ("…", '…', """…""", r"…"). Liefert {value, end} oder null.
function readString(src, i) {
	let raw = false;
	if (src[i] === 'r' && (src[i + 1] === '"' || src[i + 1] === "'")) { raw = true; i++; }
	const q = src[i];
	if (q !== '"' && q !== "'") return null;
	const triple = src.substr(i, 3) === q.repeat(3);
	let j = i + (triple ? 3 : 1);
	let v = '';
	while (j < src.length) {
		if (triple ? src.substr(j, 3) === q.repeat(3) : src[j] === q) {
			return { value: v, end: j + (triple ? 3 : 1) };
		}
		const c = src[j];
		if (c === '\n' && !triple) return null;
		if (c === '\\' && !raw) {
			const n = src[j + 1];
			const map = { n: '\n', t: '\t', r: '\r', '"': '"', "'": "'", '\\': '\\', a: '\x07', b: '\b', f: '\f', v: '\v' };
			if (n === '\n') { j += 2; continue; }
			if (n in map) { v += map[n]; j += 2; continue; }
			if (n === 'u') { v += String.fromCodePoint(parseInt(src.substr(j + 2, 4), 16)); j += 6; continue; }
			if (n === 'U') { v += String.fromCodePoint(parseInt(src.substr(j + 2, 6), 16)); j += 8; continue; }
			v += n; j += 2; continue;
		}
		v += c;
		j++;
	}
	return null;
}

function lineOf(src, i) {
	let n = 1;
	for (let k = 0; k < i; k++) if (src.charCodeAt(k) === 10) n++;
	return n;
}

// alle Textliterale eines Bereichs: [{value, start, end, key}] – key = Schlüssel, falls der Text Wert von "key": ist,
// isKey = Text ist selbst ein Schlüssel (danach folgt ':')
function literals(src, from, to) {
	const out = [];
	let i = from;
	let lastKey = null;
	while (i < to) {
		const c = src[i];
		if (c === '#') { while (i < to && src[i] !== '\n') i++; continue; }
		if (c === '"' || c === "'" || (c === 'r' && (src[i + 1] === '"' || src[i + 1] === "'") && !/\w/.test(src[i - 1] || ''))) {
			if ((src[i - 1] === '&' || src[i - 1] === '^')) { const s = readString(src, i); i = s ? s.end : i + 1; continue; }
			const s = readString(src, i);
			if (!s) { i++; continue; }
			// "a" + "b" (auch über Zeilen) zusammensetzen
			for (;;) {
				let q = s.end;
				while (q < to && /[\s\\]/.test(src[q])) q++;
				if (src[q] !== '+') break;
				q++;
				while (q < to && /[\s\\]/.test(src[q])) q++;
				const s2 = readString(src, q);
				if (!s2) break;
				s.value += s2.value;
				s.end = s2.end;
			}
			let k = s.end;
			while (k < to && (src[k] === ' ' || src[k] === '\t')) k++;
			const isKey = src[k] === ':' && src[k + 1] !== '=';
			out.push({ value: s.value, start: i, end: s.end, key: lastKey, isKey });
			lastKey = isKey ? s.value : null;
			i = s.end;
			continue;
		}
		if (c === ',' || c === '{' || c === '[' || c === '\n') lastKey = null;
		i++;
	}
	return out;
}

function addMsg(msgs, id, ref, plural, ctx) {
	if (id === '') return;
	const key = (ctx ? ctx + '\x04' : '') + id;
	if (!msgs.has(key)) msgs.set(key, { id, ctx: ctx || '', plural: plural || '', refs: [] });
	const m = msgs.get(key);
	if (plural && !m.plural) m.plural = plural;
	if (m.refs.length < 4 && !m.refs.includes(ref)) m.refs.push(ref);
}

function extract() {
	const files = walk(path.join(ROOT, 'scripts'), []).sort();
	const msgs = new Map();
	for (const f of files) {
		const src = fs.readFileSync(f, 'utf8');
		const rel = path.relative(ROOT, f).replace(/\\/g, '/');
		// tr(…) / tr_n(…) / atr(…) / Loc.t(…)
		const re = /(?<![\w.])(?:tr|atr|tr_n|atr_n|Loc\.t|Loc\.tn)\s*\(\s*/g;
		let m;
		while ((m = re.exec(src))) {
			// in Kommentaren überspringen
			const ls = src.lastIndexOf('\n', m.index) + 1;
			const before = src.slice(ls, m.index);
			if (/^\s*#/.test(before) || (before.includes('#') && !/["']/.test(before))) continue;
			let s = readString(src, m.index + m[0].length);
			if (!s) continue;
			// "a" + "b" (auch über Zeilen) zusammensetzen
			for (;;) {
				let k = s.end;
				while (/[\s\\]/.test(src[k])) k++;
				if (src[k] !== '+') break;
				k++;
				while (/[\s\\]/.test(src[k])) k++;
				const s2 = readString(src, k);
				if (!s2) break;
				s = { value: s.value + s2.value, end: s2.end };
			}
			const name = m[0].replace(/\s*\(\s*$/, '');
			let plural = '', ctx = '';
			let k = s.end;
			while (/\s/.test(src[k])) k++;
			if (src[k] === ',') {
				k++;
				while (/[\s\\]/.test(src[k])) k++;
				const s2 = readString(src, k);
				if (s2) { if (name.endsWith('_n') || name === 'Loc.tn') plural = s2.value; else ctx = s2.value; }
			}
			addMsg(msgs, s.value, rel + ':' + lineOf(src, m.index), plural, ctx);
		}
		// Markierungen
		const lines = src.split('\n');
		let off = 0;
		let block = null;   // {keys: Set|null}
		for (let n = 0; n < lines.length; n++) {
			const line = lines[n];
			const b = line.match(/^\s*#\s*i18n-begin\b\s*([\w,*]*)/);
			const e = /^\s*#\s*i18n-end\b/.test(line);
			const single = /#\s*i18n\s*$/.test(line);
			const take = (from, to, keys) => {
				for (const l of literals(src, from, to)) {
					if (l.isKey) continue;
					if (keys && !keys.has(l.key)) continue;
					if (!/[A-Za-zÄÖÜäöüß]/.test(l.value)) continue;
					if (/^[a-z0-9_]+$/.test(l.value)) continue;   // ids ("close", "reset" …)
					addMsg(msgs, l.value, rel + ':' + lineOf(src, l.start));
				}
			};
			if (b) {
				const list = b[1].trim();
				block = { keys: list && list !== '*' ? new Set(list.split(',')) : null, start: off + line.length + 1 };
			} else if (e && block) {
				take(block.start, off, block.keys);
				block = null;
			} else if (single && !block) {
				take(off, off + line.length, null);
			}
			off += line.length + 1;
		}
	}
	// Namen der Feature-Setups (setups/index.json, angezeigt ohne „(Datum ?)“)
	const idx = JSON.parse(fs.readFileSync(path.join(ROOT, 'setups/index.json'), 'utf8'));
	for (const e of idx.setups) {
		const i = e.name.indexOf(' (');
		addMsg(msgs, i < 0 ? e.name : e.name.slice(0, i), 'setups/index.json');
		if (i >= 0) addMsg(msgs, e.name.slice(i + 1), 'setups/index.json');      // Zusatz wie „(Datum ?)“ (Loc.setup_name)
	}
	// Bauteil-Namen (setups/parts.json): nur in Meldungen übersetzt („Gegen … gefahren!“), Tricknamen bleiben
	const parts = JSON.parse(fs.readFileSync(path.join(ROOT, 'setups/parts.json'), 'utf8'));
	const names = new Set();
	(function walkJ(v) {
		if (Array.isArray(v)) v.forEach(walkJ);
		else if (v && typeof v === 'object') for (const k in v) { if (k === 'name' && typeof v[k] === 'string') names.add(v[k]); else walkJ(v[k]); }
	})(parts);
	for (const n of names) addMsg(msgs, n, 'setups/parts.json');
	return msgs;
}

function poEsc(s) {
	return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\t/g, '\\t').replace(/\r/g, '\\r').replace(/\n/g, '\\n');
}

function poStr(kw, s) {
	if (!s.includes('\n') || s.indexOf('\n') === s.length - 1) return `${kw} "${poEsc(s)}"\n`;
	const parts = s.split(/(?<=\n)/);
	return `${kw} ""\n` + parts.map((p) => `"${poEsc(p)}"\n`).join('');
}

function poUnesc(s) {
	return s.replace(/\\(.)/g, (_, c) => ({ n: '\n', t: '\t', r: '\r', '"': '"', '\\': '\\' }[c] ?? c));
}

// .po lesen: Map key -> {id, ctx, plural, str: [..], refs}
function readPo(file) {
	const out = new Map();
	if (!fs.existsSync(file)) return { header: null, msgs: out };
	const txt = fs.readFileSync(file, 'utf8');
	let header = null;
	for (const chunk of txt.split(/\n\s*\n/)) {
		const e = { id: null, ctx: '', plural: '', str: [], refs: [], fuzzy: false };
		let cur = null;
		for (const raw of chunk.split('\n')) {
			const line = raw.trim();
			if (line.startsWith('#,') && line.includes('fuzzy')) e.fuzzy = true;
			if (line.startsWith('#')) continue;
			let mm;
			if ((mm = line.match(/^msgctxt\s+"(.*)"$/))) { e.ctx = poUnesc(mm[1]); cur = ['ctx']; }
			else if ((mm = line.match(/^msgid_plural\s+"(.*)"$/))) { e.plural = poUnesc(mm[1]); cur = ['plural']; }
			else if ((mm = line.match(/^msgid\s+"(.*)"$/))) { e.id = poUnesc(mm[1]); cur = ['id']; }
			else if ((mm = line.match(/^msgstr(?:\[(\d+)\])?\s+"(.*)"$/))) { const ix = +(mm[1] || 0); e.str[ix] = poUnesc(mm[2]); cur = ['str', ix]; }
			else if ((mm = line.match(/^"(.*)"$/)) && cur) {
				const v = poUnesc(mm[1]);
				if (cur[0] === 'str') e.str[cur[1]] += v; else e[cur[0]] += v;
			}
		}
		if (e.id === null) continue;
		if (e.id === '' && !e.ctx) { header = e.str[0]; continue; }
		out.set((e.ctx ? e.ctx + '\x04' : '') + e.id, e);
	}
	return { header, msgs: out };
}

const LANGS = {
	en: { name: 'English', plural: 'nplurals=2; plural=(n != 1);' },
	fr: { name: 'French', plural: 'nplurals=2; plural=(n > 1);' },
	es: { name: 'Spanish', plural: 'nplurals=2; plural=(n != 1);' },
	nl: { name: 'Dutch', plural: 'nplurals=2; plural=(n != 1);' },
	pl: { name: 'Polish', plural: 'nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);' },
	cs: { name: 'Czech', plural: 'nplurals=3; plural=(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2;' },
	pt_BR: { name: 'Portuguese (Brazil)', plural: 'nplurals=2; plural=(n > 1);' },
};

function header(lang) {
	const h = lang ? LANGS[lang] : null;
	return [
		'Project-Id-Version: WakeTheHack',
		'MIME-Version: 1.0',
		'Content-Type: text/plain; charset=UTF-8',
		'Content-Transfer-Encoding: 8bit',
		...(h ? [`Language: ${lang}`, `Plural-Forms: ${h.plural}`] : []),
		'X-Source-Language: de',
		'',
	].join('\n');
}

function writePo(file, lang, msgs, trans) {
	let out = lang ? `# ${LANGS[lang].name} – WakeTheHack\n` : '# WakeTheHack – Vorlage (Ausgangstext Deutsch)\n';
	out += 'msgid ""\n' + poStr('msgstr', header(lang)) + '\n';
	const nplur = lang ? +LANGS[lang].plural.match(/nplurals=(\d)/)[1] : 2;
	for (const [key, m] of msgs) {
		for (const r of m.refs) out += `#: ${r}\n`;
		const t = trans ? trans.get(key) : null;
		if (t && t.fuzzy) out += '#, fuzzy\n';
		if (m.ctx) out += poStr('msgctxt', m.ctx);
		out += poStr('msgid', m.id);
		if (m.plural) {
			out += poStr('msgid_plural', m.plural);
			for (let i = 0; i < nplur; i++) out += poStr(`msgstr[${i}]`, (t && t.str[i]) || '');
		} else {
			out += poStr('msgstr', (t && t.str[0]) || '');
		}
		out += '\n';
	}
	fs.writeFileSync(file, out);
}

function langFiles() {
	return Object.keys(LANGS);
}

function cmdExtract() {
	fs.mkdirSync(LOCALE, { recursive: true });
	const msgs = extract();
	writePo(POT, null, msgs, null);
	for (const lang of langFiles()) {
		const f = path.join(LOCALE, lang + '.po');
		const { msgs: old } = readPo(f);
		writePo(f, lang, msgs, old);
	}
	console.log(`${msgs.size} Texte -> locale/messages.pot, ${langFiles().length} Sprachen abgeglichen`);
}

function cmdStats() {
	const { msgs } = readPo(POT);
	for (const lang of langFiles()) {
		const { msgs: t } = readPo(path.join(LOCALE, lang + '.po'));
		let done = 0;
		for (const [k] of msgs) { const e = t.get(k); if (e && e.str[0]) done++; }
		console.log(`${lang.padEnd(6)} ${done}/${msgs.size}${done < msgs.size ? `  (fehlt ${msgs.size - done})` : ''}`);
	}
}

function cmdMissing(lang, max) {
	const { msgs } = readPo(POT);
	const { msgs: t } = readPo(path.join(LOCALE, lang + '.po'));
	const out = {};
	let n = 0;
	for (const [k, m] of msgs) {
		const e = t.get(k);
		if (e && e.str[0]) continue;
		out[k] = m.plural ? ['', ''] : '';
		if (++n >= max) break;
	}
	process.stdout.write(JSON.stringify(out, null, '\t') + '\n');
}

function cmdApply(lang, file) {
	const data = JSON.parse(fs.readFileSync(file, 'utf8'));
	const f = path.join(LOCALE, lang + '.po');
	const { msgs: t } = readPo(f);
	const { msgs } = readPo(POT);
	let n = 0, unknown = [];
	for (const k in data) {
		if (!msgs.has(k)) { unknown.push(k); continue; }
		const m = msgs.get(k);
		const v = data[k];
		t.set(k, { id: m.id, ctx: m.ctx, plural: m.plural, str: Array.isArray(v) ? v : [v], refs: [] });
		n++;
	}
	writePo(f, lang, msgs, t);
	console.log(`${lang}: ${n} übernommen`);
	if (unknown.length) console.log(`unbekannt (${unknown.length}):\n` + unknown.map((u) => '  ' + JSON.stringify(u)).join('\n'));
}

function placeholders(s) {
	return (s.replace(/%%/g, '').match(/%(?:\d+\$)?[-+0#]*\d*(?:\.\d+)?[sdifxXcv]/g) || []).sort().join(' ');
}

function cmdCheck() {
	const { msgs } = readPo(POT);
	let bad = 0;
	for (const lang of langFiles()) {
		const { msgs: t } = readPo(path.join(LOCALE, lang + '.po'));
		for (const [k, m] of msgs) {
			const e = t.get(k);
			if (!e) continue;
			for (const s of e.str) {
				if (s && placeholders(s) !== placeholders(m.id)) {
					console.log(`${lang}: Platzhalter ${JSON.stringify(placeholders(m.id))} != ${JSON.stringify(placeholders(s))}\n   ${JSON.stringify(m.id)}\n   ${JSON.stringify(s)}`);
					bad++;
				}
			}
		}
	}
	console.log(bad ? `${bad} Fehler` : 'Platzhalter ok');
	process.exitCode = bad ? 1 : 0;
}

const [cmd, a, b] = process.argv.slice(2);
if (cmd === 'extract') cmdExtract();
else if (cmd === 'stats') cmdStats();
else if (cmd === 'missing') cmdMissing(a, b ? +b : Infinity);
else if (cmd === 'apply') cmdApply(a, b);
else if (cmd === 'check') cmdCheck();
else console.log('node tools/i18n.js extract | stats | missing LANG [N] | apply LANG FILE | check');
