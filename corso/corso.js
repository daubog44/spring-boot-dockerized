/*
 * Il corso d'esame. Legge window.CORSO, che `task learn` scrive in
 * contenuti.js, e disegna lezioni, guide e la mappa del progetto.
 * Niente librerie e niente rete: la pagina si apre col doppio clic.
 */
(() => {
  'use strict';

  const CORSO = window.CORSO;
  const pagina = document.getElementById('pagina');
  const indice = document.getElementById('indice');
  const sommario = document.getElementById('sommario');

  // --- La memoria del browser, se c'e' --------------------------------------
  // In una finestra privata, o con i dati dei siti bloccati, localStorage non
  // c'e' o lancia un'eccezione: il corso funziona lo stesso, senza ricordare.

  const memoria = {
    leggi(chiave, predefinito) {
      try {
        const v = localStorage.getItem(chiave);
        return v === null ? predefinito : JSON.parse(v);
      } catch (e) {
        return predefinito;
      }
    },
    scrivi(chiave, valore) {
      try { localStorage.setItem(chiave, JSON.stringify(valore)); } catch (e) { /* si va avanti */ }
    },
  };
  const K_FATTE = 'corso-esame-fatte';
  const K_SPUNTE = 'corso-esame-spunte';
  const K_TEMA = 'corso-esame-tema';

  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const unesc = (s) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&');
  // Per cercare: minuscole e senza accenti, cosi' "citta" trova "città".
  const piano = (s) => s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

  // --- Il tema -----------------------------------------------------------------

  const TEMI = ['sistema', 'chiaro', 'scuro'];
  function applicaTema(t, iniziale) {
    const root = document.documentElement;
    // All'avvio, con "sistema", non si tocca niente: decide chi ospita la pagina.
    if (!(iniziale && t === 'sistema')) {
      if (t === 'chiaro') root.setAttribute('data-theme', 'light');
      else if (t === 'scuro') root.setAttribute('data-theme', 'dark');
      else root.removeAttribute('data-theme');
    }
    const b = document.getElementById('tema');
    if (b) b.innerHTML = '<span class="scritta">Tema: </span>' + t;
  }

  // --- Markdown ------------------------------------------------------------------
  // Il sottoinsieme che usano le guide e le lezioni: titoli, paragrafi, elenchi
  // (anche annidati e con le caselle), tabelle, citazioni, codice recintato,
  // righe orizzontali; dentro le righe codice, grassetto, corsivo, barrato e
  // link. L'HTML scritto nel testo si mostra com'e', non si esegue.

  const RE_FENCE = /^(\s*)(`{3,}|~{3,})(.*)$/;
  const RE_HEAD = /^(#{1,6})\s+(.*?)\s*#*\s*$/;
  const RE_HR = /^\s{0,3}([-*_])(?:\s*\1){2,}\s*$/;
  const RE_QUOTE = /^\s{0,3}>/;
  const RE_ITEM = /^(\s*)([-*+]|\d{1,9}[.)])(\s+|$)(.*)$/;
  const RE_TSEP = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;
  const vuota = (l) => l === undefined || /^\s*$/.test(l);
  const rientro = (l) => l.match(/^\s*/)[0].replace(/\t/g, '    ').length;
  const eTabella = (l, dopo) => l.includes('|') && dopo !== undefined && dopo.includes('-') && RE_TSEP.test(dopo);
  const ordinata = (m) => /\d/.test(m[2]);

  function iniziaBlocco(l, dopo) {
    return RE_FENCE.test(l) || RE_HEAD.test(l) || RE_HR.test(l) || RE_QUOTE.test(l) ||
      (RE_ITEM.test(l) && rientro(l) < 4) || eTabella(l, dopo);
  }

  // Gli id dei titoli come li fa GitHub, cosi' i link #ancora delle guide
  // funzionano qui come la'.
  function slugger() {
    const visti = new Map();
    return (testo) => {
      const s = testo.trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s/g, '-');
      const n = visti.get(s) || 0;
      visti.set(s, n + 1);
      return n ? s + '-' + n : s;
    };
  }

  function blocchi(righe, ctx) {
    const out = [];
    let i = 0;
    while (i < righe.length) {
      const r = righe[i];
      if (vuota(r)) { i++; continue; }

      // Commenti: nelle lezioni portano i metadati, e non si mostrano.
      if (/^\s*<!--/.test(r)) {
        while (i < righe.length && !righe[i].includes('-->')) i++;
        i++;
        continue;
      }

      let m = r.match(RE_FENCE);
      if (m) {
        const quanto = m[1].length;
        const recinto = m[2];
        const chiude = new RegExp('^\\s*' + (recinto[0] === '`' ? '`' : '~') + '{' + recinto.length + ',}\\s*$');
        const corpo = [];
        i++;
        while (i < righe.length && !chiude.test(righe[i])) {
          corpo.push(righe[i].slice(Math.min(quanto, rientro(righe[i]))));
          i++;
        }
        i++;
        out.push(codice(corpo.join('\n'), m[3].trim()));
        continue;
      }

      m = r.match(RE_HEAD);
      if (m) { out.push(titolo(m[1].length, m[2], ctx)); i++; continue; }

      if (RE_HR.test(r)) { out.push('<hr>'); i++; continue; }

      if (RE_QUOTE.test(r)) {
        const corpo = [];
        while (i < righe.length && RE_QUOTE.test(righe[i])) {
          corpo.push(righe[i].replace(/^\s{0,3}>\s?/, ''));
          i++;
        }
        out.push(citazione(corpo, ctx));
        continue;
      }

      if (eTabella(r, righe[i + 1])) {
        const corpo = [r, righe[i + 1]];
        i += 2;
        while (i < righe.length && !vuota(righe[i]) && righe[i].includes('|')) { corpo.push(righe[i]); i++; }
        out.push(tabella(corpo, ctx));
        continue;
      }

      if (RE_ITEM.test(r) && rientro(r) < 4) {
        const esito = elenco(righe, i, ctx);
        out.push(esito.html);
        i = esito.dopo;
        continue;
      }

      const par = [r.trim()];
      i++;
      while (i < righe.length && !vuota(righe[i]) && !iniziaBlocco(righe[i], righe[i + 1])) {
        par.push(righe[i].replace(/^\s+/, ''));
        i++;
      }
      out.push('<p>' + riga(par.join('\n'), ctx) + '</p>');
    }
    return out.join('\n');
  }

  function titolo(livello, testo, ctx) {
    const html = riga(testo, ctx);
    const pulito = unesc(html.replace(/<[^>]+>/g, ''));
    const id = ctx.slug(pulito);
    if (livello === 1 && !ctx.titolo) {
      ctx.titolo = pulito;
      // Il titolo della pagina lo disegna l'intestazione: qui non si ripete.
      if (ctx.saltaH1) return '';
    }
    ctx.titoli.push({ livello, id, testo: pulito });
    return `<h${livello} id="${esc(id)}">${html}</h${livello}>`;
  }

  function citazione(righe, ctx) {
    const html = blocchi(righe, ctx);
    const m = html.match(/^<p><strong>([^<]+)<\/strong>/);
    let classe = '';
    if (m) {
      const parola = piano(m[1]);
      if (/^(attenzione|trappola|occhio|l'unica trappola)/.test(parola)) classe = 'attenzione';
      else if (/^(prova|esercizio|tocca a te|fallo tu)/.test(parola)) classe = 'prova';
      else if (/^(fatto quando|hai finito|in pratica)/.test(parola)) classe = 'fatto';
    }
    return `<blockquote${classe ? ` class="${classe}"` : ''}>${html}</blockquote>`;
  }

  function celle(r) {
    let s = r.trim();
    if (s.startsWith('|')) s = s.slice(1);
    if (s.endsWith('|') && !s.endsWith('\\|')) s = s.slice(0, -1);
    const out = [];
    let cur = '';
    let dentroCodice = false;
    for (let k = 0; k < s.length; k++) {
      const c = s[k];
      if (c === '\\' && s[k + 1] === '|') { cur += '\\|'; k++; continue; }
      if (c === '`') dentroCodice = !dentroCodice;
      if (c === '|' && !dentroCodice) { out.push(cur.trim()); cur = ''; continue; }
      cur += c;
    }
    out.push(cur.trim());
    return out;
  }

  function tabella(righe, ctx) {
    const allinea = celle(righe[1]).map((c) => (/^:-+:$/.test(c) ? 'center' : /-+:$/.test(c) ? 'right' : ''));
    const cella = (tag, c, k) => `<${tag}${allinea[k] ? ` style="text-align:${allinea[k]}"` : ''}>${riga(c, ctx)}</${tag}>`;
    let html = '<div class="tabella"><table><thead><tr>' + celle(righe[0]).map((c, k) => cella('th', c, k)).join('') + '</tr></thead><tbody>';
    for (const r of righe.slice(2)) html += '<tr>' + celle(r).map((c, k) => cella('td', c, k)).join('') + '</tr>';
    return html + '</tbody></table></div>';
  }

  function elenco(righe, inizio, ctx) {
    const primo = righe[inizio].match(RE_ITEM);
    const base = rientro(righe[inizio]);
    const numerato = ordinata(primo);
    const voci = [];
    let i = inizio;
    let larga = false;
    while (i < righe.length) {
      const m = righe[i].match(RE_ITEM);
      if (!m || rientro(righe[i]) !== base || ordinata(m) !== numerato) break;
      const dentro = base + m[2].length + Math.max(1, m[3].length);
      const corpo = [m[4]];
      i++;
      while (i < righe.length) {
        const l = righe[i];
        if (vuota(l)) {
          let j = i + 1;
          while (j < righe.length && vuota(righe[j])) j++;
          if (j < righe.length && rientro(righe[j]) > base) { corpo.push(''); i++; continue; }
          const dopo = j < righe.length ? righe[j].match(RE_ITEM) : null;
          if (dopo && rientro(righe[j]) === base && ordinata(dopo) === numerato) { larga = true; i = j; }
          break;
        }
        if (rientro(l) > base) { corpo.push(l.slice(Math.min(dentro, rientro(l)))); i++; continue; }
        // Riga pigra: continua il paragrafo della voce senza rientro.
        if (!iniziaBlocco(l, righe[i + 1]) && !vuota(corpo[corpo.length - 1])) { corpo.push(l.trim()); i++; continue; }
        break;
      }
      voci.push(corpo);
    }

    const tag = numerato ? 'ol' : 'ul';
    const partenza = numerato ? parseInt(primo[2], 10) : 1;
    let html = `<${tag}${numerato && partenza !== 1 ? ` start="${partenza}"` : ''}>`;
    for (const corpo of voci) {
      let testo = corpo;
      let casella = null;
      const c = testo[0].match(/^\[( |x|X)\]\s+(.*)$/);
      if (c) {
        casella = c[1] !== ' ';
        testo = [c[2], ...testo.slice(1)];
      }
      let interno = blocchi(testo, ctx);
      if (!larga) interno = interno.replace(/^<p>([\s\S]*?)<\/p>/, '$1');
      if (casella !== null) {
        const chiave = ctx.chiave + '#' + ctx.caselle++;
        html += `<li class="compito"><label><input type="checkbox" data-spunta="${esc(chiave)}"${casella ? ' checked' : ''}><span>${interno}</span></label></li>`;
      } else {
        html += `<li>${interno}</li>`;
      }
    }
    return { html: html + `</${tag}>`, dopo: i };
  }

  function riga(testo, ctx) {
    const pezzi = [];
    const metti = (html) => '\u0000' + (pezzi.push(html) - 1) + '\u0000';

    // Il codice fra apici inversi: dentro non vale nient'altro.
    testo = testo.replace(/(`+)([\s\S]*?[^`])\1(?!`)/g, (m, a, c) => metti('<code>' + esc(c.replace(/^ ([\s\S]*) $/, '$1')) + '</code>'));
    // I caratteri protetti con la barra rovesciata.
    testo = testo.replace(/\\([\\`*_{}[\]()#+\-.!|<>~])/g, (m, c) => metti(esc(c)));
    testo = esc(testo);
    // Link (e immagini, che qui diventano link: il corso non ne ha).
    testo = testo.replace(/!?\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;[^&]*&quot;)?\)/g, (m, t, url) => {
      const dest = ctx.link(unesc(url));
      const attr = dest.esterno ? ' target="_blank" rel="noopener"' : '';
      return metti(`<a href="${esc(dest.href)}"${attr}>`) + t + metti('</a>');
    });
    testo = testo.replace(/&lt;(https?:\/\/[^\s&]+)&gt;/g, (m, u) => metti(`<a href="${esc(u)}" target="_blank" rel="noopener">${esc(u)}</a>`));
    testo = testo
      .replace(/\*\*(?=\S)([\s\S]*?\S)\*\*/g, '<strong>$1</strong>')
      .replace(/__(?=\S)([\s\S]*?\S)__/g, '<strong>$1</strong>')
      .replace(/(^|[^\w*])\*(?=[^\s*])([\s\S]*?[^\s*])\*(?![\w*])/g, '$1<em>$2</em>')
      .replace(/(^|[^\w])_(?=\S)([\s\S]*?\S)_(?!\w)/g, '$1<em>$2</em>')
      .replace(/~~(?=\S)([\s\S]*?\S)~~/g, '<del>$1</del>')
      .replace(/ {2,}\n/g, '<br>\n');
    let prima;
    do {
      prima = testo;
      testo = testo.replace(/\u0000(\d+)\u0000/g, (m, n) => pezzi[+n]);
    } while (testo !== prima);
    return testo;
  }

  // --- Il codice, colorato -------------------------------------------------------
  // Un giro solo sul testo: a ogni posizione vince la prima regola che
  // combacia. Basta per leggere, non e' un compilatore.

  const PAROLE_JAVA = 'abstract|boolean|break|case|catch|char|class|default|do|double|else|enum|extends|final|finally|float|for|if|implements|import|instanceof|int|interface|long|new|null|package|private|protected|public|record|return|short|static|super|switch|this|throw|throws|true|false|try|var|void|while|yield';
  const LINGUE = {
    java: [
      [/\/\/[^\n]*|\/\*[\s\S]*?\*\//y, 'c'],
      [/"""[\s\S]*?"""|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])'/y, 's'],
      [/@[A-Za-z_]\w*/y, 'a'],
      [new RegExp('\\b(?:' + PAROLE_JAVA + ')\\b', 'y'), 'k'],
      [/\b\d[\d_]*(?:\.\d+)?[LlFfDd]?\b/y, 'n'],
      [/\b[A-Z][A-Za-z0-9_]*\b/y, 't'],
    ],
    yaml: [
      [/#[^\n]*/y, 'c'],
      [/\$\{[^}\n]*\}/y, 'v'],
      [/"(?:\\.|[^"\\\n])*"|'[^'\n]*'/y, 's'],
      [/(?:^|(?<=\n))[ \t]*(?:- )?[\w.-]+(?=:(?:[ \t]|$))/my, 'k'],
      [/\b\d+\b/y, 'n'],
    ],
    bash: [
      [/#[^\n]*/y, 'c'],
      [/"(?:\\.|[^"\\])*"|'[^'\n]*'/y, 's'],
      [/\$\{?[A-Za-z_][\w]*\}?|\$\(/y, 'v'],
      [/\b[A-Z][A-Z0-9_]*(?==)/y, 'v'],
      [/(?:^|(?<=\n))[ \t]*(?:task|git|cd|docker|curl|powershell|bash|ls|cat|echo|winget|choco)\b/my, 'k'],
      [/(?:^|(?<=\n))[ \t]*\.?\.?\/?mvnw(?:\.cmd)?\b/my, 'k'],
    ],
    xml: [
      [/<!--[\s\S]*?-->/y, 'c'],
      [/<\/?[\w:.-]+|\/?>/y, 'k'],
      [/[\w:-]+(?==)/y, 'a'],
      [/"[^"]*"|'[^']*'/y, 's'],
      [/\$\{[^}]*\}/y, 'v'],
    ],
    sql: [
      [/--[^\n]*/y, 'c'],
      [/'(?:''|[^'])*'/y, 's'],
      [/\b(?:select|from|where|insert|into|values|update|set|delete|create|table|database|grant|all|privileges|on|to|primary|key|foreign|references|not|null|and|or|join|order|by|group|varchar|integer|bigint|boolean|date|numeric|constraint|check|unique|default)\b/iy, 'k'],
      [/\b\d+\b/y, 'n'],
    ],
    json: [
      [/"(?:\\.|[^"\\])*"(?=\s*:)/y, 'k'],
      [/"(?:\\.|[^"\\])*"/y, 's'],
      [/\b(?:true|false|null)\b|-?\b\d+(?:\.\d+)?\b/y, 'n'],
    ],
    dockerfile: [
      [/#[^\n]*/y, 'c'],
      [/(?:^|(?<=\n))[ \t]*(?:FROM|RUN|COPY|WORKDIR|ARG|ENV|ENTRYPOINT|CMD|EXPOSE|LABEL|USER|VOLUME)\b|\bAS\b/my, 'k'],
      [/\$\{?\w+\}?/y, 'v'],
      [/"[^"\n]*"/y, 's'],
    ],
  };
  const ALIAS = { sh: 'bash', shell: 'bash', powershell: 'bash', ps1: 'bash', console: 'bash', cmd: 'bash', yml: 'yaml', properties: 'yaml', html: 'xml', thymeleaf: 'xml', pom: 'xml', docker: 'dockerfile' };
  const NOMI = { bash: 'terminale', java: 'Java', yaml: 'YAML', xml: 'XML', sql: 'SQL', json: 'JSON', dockerfile: 'Dockerfile', mermaid: 'diagramma mermaid', text: 'testo' };

  function evidenzia(testo, lingua) {
    const regole = LINGUE[ALIAS[lingua] || lingua];
    if (!regole) return esc(testo);
    let out = '';
    let pos = 0;
    let piatto = '';
    while (pos < testo.length) {
      let preso = false;
      for (const [re, classe] of regole) {
        re.lastIndex = pos;
        const m = re.exec(testo);
        if (m && m[0].length) {
          out += esc(piatto) + `<span class="t-${classe}">${esc(m[0])}</span>`;
          piatto = '';
          pos += m[0].length;
          preso = true;
          break;
        }
      }
      if (!preso) {
        // Una parola intera alla volta: "int" dentro "print" non e' una parola chiave.
        const parola = /[\w$]+|[^\w$]/y;
        parola.lastIndex = pos;
        const m = parola.exec(testo);
        piatto += m[0];
        pos += m[0].length;
      }
    }
    return out + esc(piatto);
  }

  function codice(testo, info) {
    const [lingua = '', ...resto] = info.split(/\s+/);
    const l = lingua.toLowerCase();
    const etichetta = resto.join(' ') || NOMI[ALIAS[l] || l] || l || 'testo';
    return '<figure class="codice"><figcaption class="testa"><span class="percorso">' + esc(etichetta) + '</span>' +
      '<button class="copia" type="button">Copia</button></figcaption>' +
      '<pre><code>' + evidenzia(testo, l) + '</code></pre></figure>';
  }

  // --- Le pagine -----------------------------------------------------------------

  const PAGINE = { lista: [], perRotta: new Map(), perFile: new Map() };
  function registra(p) {
    PAGINE.lista.push(p);
    PAGINE.perRotta.set(p.rotta, p);
    PAGINE.perFile.set(p.file, p);
    return p;
  }

  function metadati(testo) {
    const meta = {};
    const m = testo.match(/<!--([\s\S]*?)-->/);
    if (m) {
      for (const pezzo of m[1].split(/\||\n/)) {
        const k = pezzo.indexOf(':');
        if (k > 0) meta[pezzo.slice(0, k).trim()] = pezzo.slice(k + 1).trim();
      }
    }
    const t = testo.match(/^#\s+(.+)$/m);
    meta.titolo = t ? t[1].trim() : '';
    return meta;
  }

  function normalizza(percorso) {
    const out = [];
    for (const parte of percorso.split('/')) {
      if (!parte || parte === '.') continue;
      if (parte === '..') out.pop();
      else out.push(parte);
    }
    return out.join('/');
  }

  // Un link scritto in un file Markdown, dal punto di vista di quel file:
  // un'altra guida o lezione diventa una pagina del corso, il resto un file
  // del progetto (la pagina sta in corso/, quindi la radice e' "..").
  function risolvi(url, daFile, rotta) {
    if (/^(https?:|mailto:)/i.test(url)) return { href: url, esterno: true };
    if (url.startsWith('#')) return { href: '#' + rotta + '/' + url.slice(1) };
    const [percorso, ancora = ''] = url.split('#');
    const cartella = daFile.includes('/') ? daFile.slice(0, daFile.lastIndexOf('/') + 1) : '';
    const pieno = normalizza(cartella + percorso);
    const p = PAGINE.perFile.get(pieno);
    if (p) return { href: '#' + p.rotta + (ancora ? '/' + ancora : '') };
    return { href: '../' + pieno + (ancora ? '#' + ancora : '') };
  }

  function contesto(p) {
    return {
      slug: slugger(),
      titoli: [],
      titolo: '',
      saltaH1: true,
      chiave: p.rotta,
      caselle: 0,
      link: (u) => risolvi(u, p.file, p.rotta),
    };
  }

  function prepara(p) {
    if (p.html === undefined) {
      const ctx = contesto(p);
      p.html = blocchi(p.testo.replace(/\r\n/g, '\n').split('\n'), ctx);
      p.titoli = ctx.titoli;
      if (!p.titolo) p.titolo = ctx.titolo || p.file;
    }
    return p;
  }

  const LEZIONI = [];
  const GUIDE = [];

  // --- Le viste --------------------------------------------------------------------

  function fatte() { return new Set(memoria.leggi(K_FATTE, [])); }

  function avanzamento() {
    const f = fatte();
    const n = LEZIONI.filter((l) => f.has(l.id)).length;
    const pct = LEZIONI.length ? Math.round((n / LEZIONI.length) * 100) : 0;
    return `<div class="avanzamento"><div class="barretta" role="progressbar" aria-valuemin="0" aria-valuemax="${LEZIONI.length}" aria-valuenow="${n}"><span style="width:${pct}%"></span></div>` +
      `<div class="conto">${n} di ${LEZIONI.length} lezioni fatte</div></div>`;
  }

  function disegnaIndice() {
    const f = fatte();
    let html = '<a class="semplice" href="#" data-rotta="">Inizio</a>' +
      '<a class="semplice" href="#p" data-rotta="p">Il tuo progetto, adesso</a>' +
      '<a class="semplice" href="giornata.html">La giornata, alla lavagna <span class="n">&#8599;</span></a>';
    let parte = null;
    LEZIONI.forEach((l, k) => {
      if (l.meta.parte !== parte) {
        parte = l.meta.parte;
        html += `<h3>${esc(parte || 'Lezioni')}</h3>`;
      }
      html += `<a href="#${esc(l.rotta)}" data-rotta="${esc(l.rotta)}"><span class="n">${String(k + 1).padStart(2, '0')}</span>` +
        `<span>${esc(l.titolo)}</span><span class="ok">${f.has(l.id) ? '&#10003;' : ''}</span></a>`;
    });
    html += '<h3>Le guide del progetto</h3>';
    for (const g of GUIDE) html += `<a class="semplice" href="#${esc(g.rotta)}" data-rotta="${esc(g.rotta)}"><span>${esc(g.titolo)}</span></a>`;
    html += '<h3>A che punto sei</h3>' + avanzamento();
    indice.innerHTML = html;
    segnaAttiva();
  }

  function segnaAttiva() {
    for (const a of indice.querySelectorAll('a[data-rotta]')) a.classList.toggle('attiva', a.dataset.rotta === rottaCorrente);
  }

  function copertina() {
    const f = fatte();
    const prossima = LEZIONI.find((l) => !f.has(l.id)) || LEZIONI[0];
    let orario = '';
    let parte = null;
    LEZIONI.forEach((l, k) => {
      if (l.meta.parte !== parte) {
        if (parte !== null) orario += '</ol>';
        parte = l.meta.parte;
        orario += `<div class="parte">${esc(parte || 'Lezioni')}</div><ol>`;
      }
      orario += `<li><a href="#${esc(l.rotta)}" class="${f.has(l.id) ? 'fatta' : ''}">` +
        `<span class="quando">${esc(l.meta.quando || String(k + 1).padStart(2, '0'))}</span>` +
        `<span class="che">${esc(l.titolo)}${l.meta.obiettivo ? `<span class="perche">${riga(l.meta.obiettivo, contesto(l))}</span>` : ''}</span>` +
        `<span class="durata">${esc(l.meta.durata || '')}</span></a></li>`;
    });
    if (parte !== null) orario += '</ol>';

    const pr = CORSO.progetto || { moduli: [] };
    const moduli = (pr.moduli || []).map((m) => `<span class="pastiglia ${esc(m.tipo)}">${esc(m.nome)}</span>`).join('');
    const guide = GUIDE.map((g) => `<li><a href="#${esc(g.rotta)}">${esc(g.titolo)}</a></li>`).join('');

    return `<div class="copertina">
      <div class="occhiello">Prova finale &middot; Spring Boot &middot; microservizi &middot; Docker</div>
      <h1>Dalla traccia alla consegna</h1>
      <p class="lede">Come si svolge l'esame con questo template, dalla A alla Z: com'e' fatto il progetto, come si monta, il codice di ogni pezzo e come si consegna. Il filo e' una traccia vera, <strong>la Biblioteca</strong>, svolta per intero nel branch <code>example/biblioteca</code>.</p>
      <div class="azioni">
        ${prossima ? `<a class="bottone primario" href="#${esc(prossima.rotta)}">${f.size ? 'Riprendi' : 'Comincia'}: ${esc(prossima.titolo)}</a>` : ''}
        <a class="bottone" href="#p">Il tuo progetto</a>
        ${avanzamento()}
      </div>
      <div class="griglia">
        <section class="orario" aria-label="Le lezioni"><h2>L'orario</h2>${orario || '<p class="vuoto">Nessuna lezione: rilancia task learn.</p>'}</section>
        <aside class="schede">
          <h2>Intanto</h2>
          <div class="scheda"><h3>Il tuo progetto, adesso</h3><p>Fotografato da <code>task learn</code> il ${esc(CORSO.generato || '')}.</p><div class="moduli">${moduli}</div><a href="#p">La mappa dei moduli &rarr;</a></div>
          <div class="scheda"><h3>La giornata, alla lavagna</h3><p>Le stesse cose in nove fasi con l'orologio dell'esame, una lavagna che le legge ad alta voce e il video.</p><a href="giornata.html">Apri la lavagna &#8599;</a></div>
          <div class="scheda"><h3>Le guide del progetto</h3><p>Sono qui dentro, con i link che portano da una all'altra.</p><ul>${guide}</ul></div>
        </aside>
      </div>
    </div>`;
  }

  function vistaLezione(p) {
    const k = LEZIONI.indexOf(p);
    const f = fatte();
    const prima = LEZIONI[k - 1];
    const dopo = LEZIONI[k + 1];
    const fatta = f.has(p.id);
    return `<article class="foglio lezione">
      <div class="timbro"><span>lezione ${String(k + 1).padStart(2, '0')} di ${LEZIONI.length}</span>` +
      (p.meta.quando ? `<span class="ora">${esc(p.meta.quando)}</span>` : '') +
      (p.meta.durata ? `<span>${esc(p.meta.durata)}</span>` : '') +
      (p.meta.parte ? `<span>${esc(p.meta.parte)}</span>` : '') + `</div>
      <h1>${esc(p.titolo)}</h1>
      ${p.meta.obiettivo ? `<p class="obiettivo"><strong class="etichetta">Alla fine della lezione</strong>${riga(p.meta.obiettivo, contesto(p))}</p>` : ''}
      <div class="contenuto">${p.html}</div>
      <div class="piede">
        <button class="bottone ${fatta ? 'fatta' : 'primario'}" type="button" data-fatta="${esc(p.id)}">${fatta ? '&#10003; Fatta' : 'Segna come fatta'}</button>
        <nav class="vicine" aria-label="Lezioni vicine">
          ${prima ? `<a class="bottone" href="#${esc(prima.rotta)}">&larr; ${esc(prima.titolo)}</a>` : ''}
          ${dopo ? `<a class="bottone" href="#${esc(dopo.rotta)}">${esc(dopo.titolo)} &rarr;</a>` : ''}
        </nav>
      </div>
    </article>`;
  }

  function vistaGuida(p) {
    return `<article class="foglio">
      <div class="timbro"><span>guida del progetto</span><span>${esc(p.file)}</span></div>
      <h1>${esc(p.titolo)}</h1>
      <div class="contenuto">${p.html}</div>
    </article>`;
  }

  const TIPI = { eureka: 'Eureka, il registro', ui: 'interfaccia Thymeleaf', rest: 'servizio REST', libreria: 'libreria condivisa' };

  function vistaProgetto() {
    const pr = CORSO.progetto || { moduli: [] };
    const moduli = pr.moduli || [];
    const righe = moduli.map((m) => `<tr><td><code>${esc(m.nome)}</code></td><td>${esc(TIPI[m.tipo] || m.tipo)}</td>` +
      `<td>${m.porta ? esc(m.porta) : ''}</td><td>${m.applicazione ? `<code>${esc(m.applicazione)}</code>` : ''}</td>` +
      `<td>${esc(m.database || '')}</td><td>${(m.entity || []).map(esc).join(', ')}</td><td>${(m.feign || []).map((x) => `<code>${esc(x)}</code>`).join(', ')}</td></tr>`).join('');
    const dto = moduli.filter((m) => m.tipo === 'libreria').flatMap((m) => m.classi || []);
    return `<article class="foglio">
      <div class="timbro"><span>fotografato da task learn il ${esc(CORSO.generato || '')}</span><span>cartella ${esc(pr.cartella || '')}/</span><span>pacchetto ${esc(pr.pacchetto || '')}</span><span>java ${esc(pr.java || '')}</span></div>
      <h1>Il tuo progetto, adesso</h1>
      <div class="contenuto">
        <p>Chi c'e', su che porta, con che nome si registra su Eureka, dove tiene i dati e chi chiama chi. E' letto dai file del progetto quando hai lanciato <code>task learn</code>: se nel frattempo hai aggiunto un modulo, rilancialo.</p>
        ${mappa(moduli)}
        <h2 id="moduli">I moduli</h2>
        <div class="tabella"><table><thead><tr><th>Modulo</th><th>Che cos'e'</th><th>Porta</th><th>Nome su Eureka</th><th>Database</th><th>Entity</th><th>Chiama</th></tr></thead><tbody>${righe}</tbody></table></div>
        <h2 id="common-dto">In common-dto</h2>
        ${dto.length ? `<p>Le classi che i servizi si passano: ${dto.map((d) => `<code>${esc(d)}</code>`).join(', ')}.</p>` : '<p>Ancora niente: e\' qui che metterai i DTO che due servizi si scambiano. Come e perche\', nella lezione su common-dto.</p>'}
      </div>
    </article>`;
  }

  // Colonne: interfacce, servizi, database. Sopra, il registro.
  function mappa(moduli) {
    const ui = moduli.filter((m) => m.tipo === 'ui');
    const rest = moduli.filter((m) => m.tipo === 'rest');
    const eureka = moduli.find((m) => m.tipo === 'eureka');
    if (!ui.length && !rest.length) {
      return '<p class="vuoto">Per ora c\'e\' solo l\'impalcatura: Eureka e common-dto. I servizi della traccia li crei con <code>task wizard</code> o <code>task new-service NAME=...</code>.</p>';
    }
    const db = [...new Set(rest.map((m) => m.database).filter((d) => /^PostgreSQL/.test(d)))].map((d) => ({ nome: d, tipo: 'db' }));
    const colonne = [ui, rest, db];
    const W = 214, H = 62, GX = 84, GY = 20, TOP = 96, LEFT = 14;
    const pos = new Map();
    colonne.forEach((col, c) => col.forEach((n, r) => pos.set(n.nome, { x: LEFT + c * (W + GX), y: TOP + r * (H + GY), c })));
    const righeMax = Math.max(1, ...colonne.map((c) => c.length));
    const larghezza = LEFT * 2 + 3 * W + 2 * GX + 40;
    const altezza = TOP + righeMax * (H + GY) + 4;
    const perApp = new Map(moduli.filter((m) => m.applicazione).map((m) => [m.applicazione.toUpperCase(), m]));

    let archi = '';
    const arco = (da, a, classe, etichetta) => {
      const s = pos.get(da);
      const t = pos.get(a);
      if (!s || !t) return;
      let d;
      let lx;
      let ly;
      if (t.c > s.c) {
        const x1 = s.x + W, y1 = s.y + H / 2, x2 = t.x - 6, y2 = t.y + H / 2;
        d = `M${x1},${y1} C${x1 + GX / 2},${y1} ${x2 - GX / 2},${y2} ${x2},${y2}`;
        lx = (x1 + x2) / 2; ly = (y1 + y2) / 2 - 6;
      } else {
        // Stessa colonna: l'arco gira a destra.
        const x1 = s.x + W, y1 = s.y + H / 2 + 8, x2 = t.x + W + 6, y2 = t.y + H / 2 - 8;
        d = `M${x1},${y1} C${x1 + 60},${y1} ${x2 + 60},${y2} ${x2},${y2}`;
        lx = x1 + 50; ly = (y1 + y2) / 2 + 4;
      }
      archi += `<path class="arco ${classe}" d="${d}" marker-end="url(#punta-${classe || 'feign'})"/>`;
      if (etichetta) archi += `<text class="etichetta" x="${lx}" y="${ly}" text-anchor="middle">${esc(etichetta)}</text>`;
    };
    for (const m of [...ui, ...rest]) {
      for (const bersaglio of m.feign || []) {
        const t = perApp.get(bersaglio.toUpperCase());
        if (t) arco(m.nome, t.nome, '', 'Feign');
      }
      if (/^PostgreSQL/.test(m.database || '')) arco(m.nome, m.database, 'db', '');
    }

    let nodi = '';
    for (const [nome, p] of pos) {
      const m = moduli.find((x) => x.nome === nome);
      const classe = m ? m.tipo : 'db';
      const sotto = m ? [m.porta ? ':' + m.porta : '', m.applicazione, /^H2/.test(m.database || '') ? 'H2' : ''].filter(Boolean).join(' · ') : 'un container, piu\' database';
      const titoloNodo = m ? nome : nome.replace(/^PostgreSQL /, 'PostgreSQL · ');
      nodi += `<g class="nodo ${classe}"><rect x="${p.x}" y="${p.y}" width="${W}" height="${H}" rx="7"/>` +
        `<text x="${p.x + 14}" y="${p.y + 26}">${esc(titoloNodo)}</text><text class="sub" x="${p.x + 14}" y="${p.y + 46}">${esc(sotto)}</text></g>`;
    }
    const reg = eureka ? `<g class="registro"><rect x="${LEFT}" y="10" width="${larghezza - LEFT * 2 - 40}" height="52" rx="7"/>` +
      `<text x="${LEFT + 14}" y="32">${esc(eureka.nome)} &#183; Eureka${eureka.porta ? ' :' + esc(eureka.porta) : ''}</text>` +
      `<text class="sub" x="${LEFT + 14}" y="50">tutti si registrano qui col loro nome, e si trovano per nome: niente indirizzi nel codice</text></g>` : '';
    return `<div class="mappa"><svg viewBox="0 0 ${larghezza} ${altezza}" role="img" aria-label="La mappa dei moduli: chi chiama chi">
      <defs>
        <marker id="punta-feign" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="punta" d="M0,0 L10,5 L0,10 z"/></marker>
        <marker id="punta-db" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="punta db" d="M0,0 L10,5 L0,10 z"/></marker>
      </defs>${reg}${archi}${nodi}</svg></div>`;
  }

  function mancaContenuto() {
    return `<article class="foglio"><div class="timbro"><span>manca corso/contenuti.js</span></div>
      <h1>Il corso si prepara con un comando</h1>
      <div class="contenuto">
        <p>Le lezioni e le guide sono file Markdown, e una pagina aperta col doppio clic non puo' leggerli da sola. Dal terminale, nella cartella del progetto:</p>
        ${codice('task learn', 'bash')}
        <p>Li raccoglie in <code>corso/contenuti.js</code> e riapre questa pagina, con dentro tutto. Senza go-task: <code>powershell -File scripts/learn.ps1</code> su Windows, <code>bash scripts/learn.sh</code> altrove.</p>
        <p>Intanto la giornata in nove fasi, con la lavagna, si apre anche cosi': <a href="giornata.html">giornata.html</a>.</p>
      </div></article>`;
  }

  // --- La ricerca --------------------------------------------------------------------

  let voci = null;
  function indicizza() {
    voci = [];
    const div = document.createElement('div');
    for (const p of PAGINE.lista) {
      prepara(p);
      div.innerHTML = p.html;
      let sezione = { p, id: '', titolo: p.titolo, testo: '' };
      const chiudi = () => { if (sezione.testo.trim()) voci.push({ ...sezione, piano: piano(sezione.titolo + ' \u0001 ' + sezione.testo) }); };
      for (const el of div.children) {
        if (/^H[1-4]$/.test(el.tagName)) {
          chiudi();
          sezione = { p, id: el.id, titolo: el.textContent, testo: '' };
        } else {
          sezione.testo += ' ' + el.textContent.replace(/\s+/g, ' ');
        }
      }
      chiudi();
    }
  }

  function cerca(domanda) {
    const parole = piano(domanda).split(/\s+/).filter((w) => w.length > 1);
    if (!parole.length) return [];
    if (!voci) indicizza();
    const trovate = [];
    for (const v of voci) {
      if (!parole.every((w) => v.piano.includes(w))) continue;
      const nelTitolo = parole.filter((w) => piano(v.titolo).includes(w)).length;
      trovate.push({ v, punti: nelTitolo * 10 + (v.p.tipo === 'lezione' ? 3 : 0) });
    }
    trovate.sort((a, b) => b.punti - a.punti);
    return trovate.slice(0, 30).map((t) => t.v);
  }

  function pezzetto(v, parole) {
    const testo = v.testo.trim();
    const pt = piano(testo);
    let k = -1;
    for (const w of parole) { k = pt.indexOf(w); if (k >= 0) break; }
    const da = Math.max(0, k - 50);
    let s = (da > 0 ? '… ' : '') + testo.slice(da, da + 150) + (testo.length > da + 150 ? ' …' : '');
    s = esc(s);
    for (const w of parole) {
      const re = new RegExp('(' + w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
      s = s.replace(re, '<mark>$1</mark>');
    }
    return s;
  }

  function mostraRisultati(domanda) {
    const box = document.getElementById('risultati');
    if (!domanda.trim()) { box.hidden = true; return; }
    const parole = piano(domanda).split(/\s+/).filter((w) => w.length > 1);
    const trovate = cerca(domanda);
    box.innerHTML = trovate.length
      ? trovate.map((v, k) => `<a href="#${esc(v.p.rotta)}${v.id ? '/' + esc(v.id) : ''}" class="${k === 0 ? 'primo' : ''}">` +
        `<span class="dove">${v.p.tipo === 'lezione' ? 'lezione' : 'guida'} &middot; ${esc(v.p.titolo)}</span>` +
        `<span class="che">${esc(v.titolo)}</span><span class="pezzo">${pezzetto(v, parole)}</span></a>`).join('')
      : '<div class="niente">Niente. Prova con una parola sola, o con il nome di un comando.</div>';
    box.hidden = false;
  }

  // --- Il giro -----------------------------------------------------------------------

  let rottaCorrente = null;
  let osservatore = null;

  function disegnaSommario(p) {
    if (osservatore) { osservatore.disconnect(); osservatore = null; }
    const titoli = p ? (p.titoli || []).filter((t) => t.livello === 2 || t.livello === 3) : [];
    if (titoli.length < 2) { sommario.innerHTML = ''; return; }
    sommario.innerHTML = '<p class="titoletto">In questa pagina</p>' +
      titoli.map((t) => `<a class="h${t.livello}" href="#${esc(p.rotta)}/${esc(t.id)}" data-id="${esc(t.id)}">${esc(t.testo)}</a>`).join('');
    if ('IntersectionObserver' in window) {
      osservatore = new IntersectionObserver((voci) => {
        for (const v of voci) {
          if (v.isIntersecting) {
            for (const a of sommario.querySelectorAll('a')) a.classList.toggle('qui', a.dataset.id === v.target.id);
          }
        }
      }, { rootMargin: '-15% 0px -70% 0px' });
      for (const t of titoli) {
        const el = document.getElementById(t.id);
        if (el) osservatore.observe(el);
      }
    }
  }

  function applicaSpunte() {
    const spunte = memoria.leggi(K_SPUNTE, {});
    for (const c of pagina.querySelectorAll('input[data-spunta]')) {
      if (c.dataset.spunta in spunte) c.checked = spunte[c.dataset.spunta];
    }
  }

  function vai() {
    const h = decodeURIComponent(location.hash.slice(1));
    let rotta = '';
    let ancora = '';
    const m = h.match(/^([ld])\/([^/]+)(?:\/(.*))?$/);
    if (m) { rotta = m[1] + '/' + m[2]; ancora = m[3] || ''; }
    else if (h === 'p' || h.startsWith('p/')) { rotta = 'p'; ancora = h.slice(2); }

    if (rotta !== rottaCorrente) {
      rottaCorrente = rotta;
      const p = PAGINE.perRotta.get(rotta);
      if (p) {
        prepara(p);
        pagina.innerHTML = p.tipo === 'lezione' ? vistaLezione(p) : vistaGuida(p);
        document.title = p.titolo + ' · Dalla traccia alla consegna';
        disegnaSommario(p);
      } else if (rotta === 'p') {
        pagina.innerHTML = vistaProgetto();
        document.title = 'Il tuo progetto · Dalla traccia alla consegna';
        disegnaSommario(null);
      } else {
        rottaCorrente = '';
        pagina.innerHTML = copertina();
        document.title = 'Dalla traccia alla consegna';
        disegnaSommario(null);
      }
      applicaSpunte();
      segnaAttiva();
      indice.classList.remove('aperto');
    }
    const bersaglio = ancora ? document.getElementById(ancora) : null;
    if (bersaglio) bersaglio.scrollIntoView();
    else if (!ancora) window.scrollTo(0, 0);
  }

  // --- Avvio -------------------------------------------------------------------------

  applicaTema(memoria.leggi(K_TEMA, 'sistema'), true);
  document.getElementById('tema').addEventListener('click', () => {
    const t = TEMI[(TEMI.indexOf(memoria.leggi(K_TEMA, 'sistema')) + 1) % TEMI.length];
    memoria.scrivi(K_TEMA, t);
    applicaTema(t, false);
  });
  document.getElementById('menu').addEventListener('click', () => indice.classList.toggle('aperto'));

  if (!CORSO) {
    pagina.innerHTML = mancaContenuto();
    indice.innerHTML = '<a class="semplice" href="giornata.html">La giornata, alla lavagna</a>';
    document.getElementById('cerca').disabled = true;
    return;
  }

  for (const l of CORSO.lezioni || []) {
    const id = l.file.split('/').pop().replace(/\.md$/, '');
    const meta = metadati(l.testo);
    LEZIONI.push(registra({ tipo: 'lezione', id, rotta: 'l/' + id, file: l.file, testo: l.testo, meta, titolo: meta.titolo }));
  }
  for (const d of CORSO.documenti || []) {
    const t = d.testo.match(/^#\s+(.+)$/m);
    GUIDE.push(registra({ tipo: 'guida', id: d.file, rotta: 'd/' + d.file, file: d.file, testo: d.testo, meta: {}, titolo: t ? t[1].replace(/[*`]/g, '').trim() : d.file }));
  }

  pagina.addEventListener('click', (e) => {
    const copia = e.target.closest('.copia');
    if (copia) {
      const testo = copia.closest('.codice').querySelector('pre').textContent;
      const fatto = () => { copia.textContent = 'Copiato'; copia.classList.add('fatto'); setTimeout(() => { copia.textContent = 'Copia'; copia.classList.remove('fatto'); }, 1600); };
      const ripiego = () => {
        const area = document.createElement('textarea');
        area.value = testo;
        document.body.appendChild(area);
        area.select();
        try { document.execCommand('copy'); fatto(); } catch (err) { /* niente */ }
        area.remove();
      };
      if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(testo).then(fatto, ripiego);
      else ripiego();
      return;
    }
    const segna = e.target.closest('[data-fatta]');
    if (segna) {
      const f = fatte();
      const id = segna.dataset.fatta;
      if (f.has(id)) f.delete(id); else f.add(id);
      memoria.scrivi(K_FATTE, [...f]);
      const ora = f.has(id);
      segna.className = 'bottone ' + (ora ? 'fatta' : 'primario');
      segna.innerHTML = ora ? '&#10003; Fatta' : 'Segna come fatta';
      disegnaIndice();
    }
  });
  pagina.addEventListener('change', (e) => {
    const c = e.target.closest('input[data-spunta]');
    if (!c) return;
    const spunte = memoria.leggi(K_SPUNTE, {});
    spunte[c.dataset.spunta] = c.checked;
    memoria.scrivi(K_SPUNTE, spunte);
  });

  const campo = document.getElementById('cerca');
  const box = document.getElementById('risultati');
  campo.addEventListener('input', () => mostraRisultati(campo.value));
  campo.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const primo = box.querySelector('a');
      if (primo) { location.hash = primo.getAttribute('href'); box.hidden = true; campo.blur(); }
    } else if (e.key === 'Escape') {
      box.hidden = true;
      campo.blur();
    }
  });
  box.addEventListener('click', (e) => { if (e.target.closest('a')) box.hidden = true; });
  document.addEventListener('click', (e) => { if (!e.target.closest('.cerca')) box.hidden = true; });
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && document.activeElement !== campo && !/input|textarea/i.test(document.activeElement.tagName)) {
      e.preventDefault();
      campo.focus();
    }
  });

  disegnaIndice();
  window.addEventListener('hashchange', vai);
  vai();
})();
