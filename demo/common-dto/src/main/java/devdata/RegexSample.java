package devdata;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.regex.Pattern;

/**
 * Una stringa che rispetta un'espressione regolare, per i campi con @Pattern:
 * "[A-Z]{2}[0-9]{3}[A-Z]{2}" diventa "AB123CD". Copre quello che si scrive
 * davvero nelle validazioni (classi, quantificatori, gruppi, alternative) e
 * alla fine controlla con Pattern.matches: se non ci riesce restituisce null,
 * e il campo viene segnalato invece di fallire in silenzio.
 */
final class RegexSample {

    private static final String UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final String LOWER = "abcdefghijklmnopqrstuvwxyz";
    private static final String DIGITS = "0123456789";
    private static final String WORD = UPPER + LOWER + DIGITS;
    private static final String PRINTABLE = WORD + " -_.,@";

    private final String re;
    private int pos;

    private RegexSample(String re) {
        this.re = re;
    }

    static String generate(String regex, Random rnd) {
        Node root;
        try {
            root = new RegexSample(regex).parseAlternatives();
        } catch (RuntimeException e) {
            return null;
        }
        for (int i = 0; i < 30; i++) {
            StringBuilder sb = new StringBuilder();
            root.emit(sb, rnd);
            String s = sb.toString();
            if (Pattern.matches(regex, s)) return s;
        }
        return null;
    }

    private interface Node {
        void emit(StringBuilder sb, Random rnd);
    }

    private record Chars(String choices) implements Node {
        public void emit(StringBuilder sb, Random rnd) {
            if (!choices.isEmpty()) sb.append(choices.charAt(rnd.nextInt(choices.length())));
        }
    }

    private record Sequence(List<Node> items) implements Node {
        public void emit(StringBuilder sb, Random rnd) {
            for (Node n : items) n.emit(sb, rnd);
        }
    }

    private record Alternatives(List<Node> options) implements Node {
        public void emit(StringBuilder sb, Random rnd) {
            options.get(rnd.nextInt(options.size())).emit(sb, rnd);
        }
    }

    private record Repeat(Node node, int min, int max) implements Node {
        public void emit(StringBuilder sb, Random rnd) {
            int n = min + (max > min ? rnd.nextInt(max - min + 1) : 0);
            for (int i = 0; i < n; i++) node.emit(sb, rnd);
        }
    }

    private boolean more() {
        return pos < re.length();
    }

    private char peek() {
        return re.charAt(pos);
    }

    private Node parseAlternatives() {
        List<Node> options = new ArrayList<>();
        options.add(parseSequence());
        while (more() && peek() == '|') {
            pos++;
            options.add(parseSequence());
        }
        return options.size() == 1 ? options.get(0) : new Alternatives(options);
    }

    private Node parseSequence() {
        List<Node> items = new ArrayList<>();
        while (more() && peek() != '|' && peek() != ')') {
            Node atom = parseAtom();
            if (atom != null) items.add(parseQuantifier(atom));
        }
        return new Sequence(items);
    }

    private Node parseAtom() {
        char c = re.charAt(pos++);
        switch (c) {
            case '^', '$':
                return null;
            case '(': {
                if (re.startsWith("?:", pos) || re.startsWith("?=", pos) || re.startsWith("?!", pos)) {
                    pos += 2;
                } else if (re.startsWith("?<", pos)) {
                    pos = re.indexOf('>', pos) + 1;
                } else if (more() && peek() == '?') {
                    // (?i) e simili: solo opzioni, nessun testo.
                    int end = re.indexOf(')', pos);
                    pos = end + 1;
                    return null;
                }
                Node inner = parseAlternatives();
                if (more() && peek() == ')') pos++;
                return inner;
            }
            case '[':
                return parseClass();
            case '.':
                return new Chars(WORD);
            case '\\':
                return new Chars(escape(re.charAt(pos++)));
            default:
                return new Chars(String.valueOf(c));
        }
    }

    private String escape(char e) {
        switch (e) {
            case 'd': return DIGITS;
            case 'w': return WORD;
            case 's': return " ";
            case 'D': return UPPER;
            case 'W': return "-";
            case 'S': return WORD;
            case 'p':
            case 'P':
                if (more() && peek() == '{') pos = re.indexOf('}', pos) + 1;
                return UPPER + LOWER;
            default: return String.valueOf(e);
        }
    }

    private Node parseClass() {
        boolean negate = more() && peek() == '^';
        if (negate) pos++;
        StringBuilder set = new StringBuilder();
        boolean first = true;
        while (more() && (peek() != ']' || first)) {
            first = false;
            char c = re.charAt(pos++);
            if (c == '\\') {
                set.append(escape(re.charAt(pos++)));
                continue;
            }
            if (more() && peek() == '-' && pos + 1 < re.length() && re.charAt(pos + 1) != ']') {
                char to = re.charAt(pos + 1);
                pos += 2;
                for (char x = c; x <= to; x++) set.append(x);
            } else {
                set.append(c);
            }
        }
        pos++; // la ]
        if (!negate) return new Chars(set.toString());
        StringBuilder allowed = new StringBuilder();
        for (char x : PRINTABLE.toCharArray()) if (set.indexOf(String.valueOf(x)) < 0) allowed.append(x);
        return new Chars(allowed.length() > 0 ? allowed.toString() : "x");
    }

    private Node parseQuantifier(Node atom) {
        if (!more()) return atom;
        char c = peek();
        int min;
        int max;
        if (c == '?') { min = 0; max = 1; pos++; }
        else if (c == '*') { min = 0; max = 3; pos++; }
        else if (c == '+') { min = 1; max = 4; pos++; }
        else if (c == '{' && re.indexOf('}', pos) > pos) {
            int end = re.indexOf('}', pos);
            String[] parts = re.substring(pos + 1, end).split(",", -1);
            try {
                min = Integer.parseInt(parts[0].trim());
                max = parts.length == 1 ? min : parts[1].isBlank() ? min + 3 : Integer.parseInt(parts[1].trim());
            } catch (NumberFormatException e) {
                return atom;
            }
            // Senza esagerare: {1,255} non vuol dire che servano 255 caratteri.
            if (max - min > 8) max = min + 8;
            pos = end + 1;
        } else {
            return atom;
        }
        if (more() && (peek() == '?' || peek() == '+')) pos++; // pigro o possessivo
        return new Repeat(atom, min, max);
    }
}
