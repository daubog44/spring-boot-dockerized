package devdata;

import java.lang.annotation.Annotation;
import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.Year;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.Random;
import java.util.UUID;

/**
 * I valori inventati: plausibili per il nome del campo (una "citta" prende
 * nomi di citta', una "email" indirizzi) e sempre dentro i vincoli che il campo
 * dichiara: lunghezza della colonna, @Size, @Min, @Max, @Digits, @Email,
 * @Past, @Future, @Pattern.
 */
final class Values {

    private static final String[] AZIENDE = {"Rossi S.r.l.", "Bianchi SpA", "Verdi & Figli", "Neri Logistica", "Gialli Trasporti", "Azzurri Import", "Ferrari Componenti", "Moretti Distribuzione"};
    private static final String[] CITTA = {"Bolzano", "Trento", "Verona", "Milano", "Bologna", "Padova", "Brescia", "Modena"};
    private static final String[] PROVINCE = {"BZ", "TN", "VR", "MI", "BO", "PD", "BS", "MO"};
    private static final String[] PERSONE = {"Mario Rossi", "Anna Bianchi", "Luca Verdi", "Giulia Neri", "Paolo Gialli", "Sara Azzurri", "Marco Ferrari", "Elena Moretti"};
    private static final String[] NOMI = {"Mario", "Anna", "Luca", "Giulia", "Paolo", "Sara", "Marco", "Elena"};
    private static final String[] COGNOMI = {"Rossi", "Bianchi", "Verdi", "Neri", "Gialli", "Azzurri", "Ferrari", "Moretti"};
    private static final String[] TITOLI = {"La casa sul lago", "Il viaggio di Marta", "Ombre sul fiume", "Le stagioni del grano", "Lettere da Trieste", "Il silenzio del bosco", "Cronache di provincia", "L'ultima estate"};
    private static final String[] DESCRIZIONI = {"Prima consegna del mese", "Ordine urgente", "Riassortimento magazzino", "Reso da cliente", "Fornitura periodica", "Campione gratuito", "Ordine ricorrente", "Spedizione parziale"};
    private static final String[] PRODOTTI = {"Vite M6", "Dado esagonale", "Cuscinetto 6203", "Guarnizione 40mm", "Molla a trazione", "Rondella piana", "Perno filettato", "Boccola in ottone"};
    private static final String[] NAZIONI = {"Italia", "Francia", "Germania", "Spagna", "Austria", "Svizzera", "Portogallo", "Grecia"};
    private static final String[] NAZIONALITA = {"Italiana", "Francese", "Tedesca", "Spagnola", "Austriaca", "Svizzera", "Portoghese", "Greca"};
    private static final String[] VIE = {"Via Roma", "Via Garibaldi", "Corso Italia", "Via Mazzini", "Piazza Duomo", "Via Verdi", "Viale Trento", "Via Dante"};
    private static final String[] CATEGORIE = {"Standard", "Premium", "Base", "Speciale", "Stagionale", "Promozione", "Nuovo arrivo", "Classico"};
    private static final String[] STATI = {"ATTIVO", "IN_ATTESA", "COMPLETATO", "ANNULLATO"};
    private static final String[] COLORI = {"Rosso", "Blu", "Verde", "Giallo", "Nero", "Bianco", "Grigio", "Arancione"};
    private static final String[] DEPOSITI = {"Magazzino Nord", "Magazzino Sud", "Deposito Centrale", "Hub Bolzano", "Deposito Est", "Magazzino Ovest", "Punto Trento", "Hub Verona"};
    private static final String[] CORSI = {"Programmazione", "Basi di dati", "Reti", "Sistemi operativi", "Analisi matematica", "Fisica", "Inglese tecnico", "Ingegneria del software"};
    private static final String[] STRUTTURE = {"Hotel Alpino", "Albergo Centrale", "Residence Lago", "Hotel Dolomiti", "B&B Il Glicine", "Agriturismo Le Vigne", "Hotel Stella", "Locanda del Ponte"};

    private Values() {
    }

    /**
     * Il generatore per un campo di una riga. new Random(seme) con semi vicini
     * (riga 1, 2, 3...) da' primi numeri quasi uguali: il seme va rimescolato,
     * o tutte le quantita' escono 48, 49, 49.
     */
    static Random random(Object... parts) {
        long h = java.util.Arrays.hashCode(parts);
        h ^= h >>> 33;
        h *= 0xff51afd7ed558ccdL;
        h ^= h >>> 33;
        h *= 0xc4ceb9fe1a85ec53L;
        h ^= h >>> 33;
        return new Random(h);
    }

    /**
     * La tabella di nomi giusta per un campo generico ("nome", "titolo") in
     * base all'entity: il nome di un Articolo e' un prodotto, quello di una
     * Categoria una categoria. Null se l'entity non dice niente.
     */
    private static String[] byContext(List<String> entity) {
        if (has(entity, "prodotto", "articolo", "item", "merce", "product", "ricambio", "componente")) return PRODOTTI;
        if (has(entity, "fornitore", "azienda", "negozio", "societa", "ditta", "store", "company", "supplier", "editore", "produttore")) return AZIENDE;
        if (has(entity, "deposito", "magazzino", "warehouse", "sede", "filiale", "cabinet", "scaffale", "reparto")) return DEPOSITI;
        if (has(entity, "categoria", "category", "tipologia", "genere", "tipo")) return CATEGORIE;
        if (has(entity, "libro", "film", "evento", "spettacolo", "album", "book", "event", "mostra", "concerto")) return TITOLI;
        if (has(entity, "corso", "materia", "course", "esame", "insegnamento")) return CORSI;
        if (has(entity, "citta", "comune", "luogo", "localita", "city")) return CITTA;
        if (has(entity, "hotel", "albergo", "struttura", "ristorante", "residence")) return STRUTTURE;
        return null;
    }

    /** I vincoli di un campo, letti dalle sue annotazioni (JPA e Bean Validation). */
    static final class Rules {
        boolean required;
        boolean unique;
        boolean email;
        boolean url;
        boolean past;
        boolean future;
        boolean orPresent;
        boolean assertTrue;
        boolean assertFalse;
        Integer minLen;
        Integer maxLen;
        BigDecimal min;
        BigDecimal max;
        boolean minExclusive;
        boolean maxExclusive;
        Integer intDigits;
        Integer fracDigits;
        String pattern;

        /**
         * Le annotazioni si riconoscono dal nome semplice: cosi' valgono sia
         * quelle di jakarta.validation sia quelle di Hibernate Validator
         * (@Length, @Range, @URL), senza dipendere da nessuna delle due.
         */
        static Rules of(Collection<Annotation> annotations, Class<?> type) {
            Rules r = new Rules();
            boolean lob = false;
            boolean longText = false;
            Integer columnLength = null;
            for (Annotation a : annotations) {
                String n = a.annotationType().getSimpleName();
                switch (n) {
                    case "Column" -> {
                        if (Boolean.FALSE.equals(attr(a, "nullable"))) r.required = true;
                        if (Boolean.TRUE.equals(attr(a, "unique"))) r.unique = true;
                        Object length = attr(a, "length");
                        if (length instanceof Integer l) columnLength = l;
                        Object definition = attr(a, "columnDefinition");
                        if (definition instanceof String d && d.toLowerCase(Locale.ROOT).matches(".*(text|clob|lob).*")) longText = true;
                        if (type == BigDecimal.class && attr(a, "precision") instanceof Integer p && p > 0) {
                            int scale = attr(a, "scale") instanceof Integer s ? s : 0;
                            r.intDigits = min(r.intDigits, p - scale);
                            r.fracDigits = min(r.fracDigits, scale);
                        }
                    }
                    case "Lob" -> lob = true;
                    case "Id", "NaturalId" -> { r.unique = true; r.required = true; }
                    case "Basic" -> { if (Boolean.FALSE.equals(attr(a, "optional"))) r.required = true; }
                    case "NotNull" -> r.required = true;
                    case "NotBlank", "NotEmpty" -> { r.required = true; r.minLen = max(r.minLen, 1); }
                    case "Size", "Length" -> {
                        r.minLen = max(r.minLen, (Integer) attr(a, "min"));
                        r.maxLen = min(r.maxLen, (Integer) attr(a, "max"));
                    }
                    case "Min" -> r.raiseMin(BigDecimal.valueOf((Long) attr(a, "value")), false);
                    case "Max" -> r.lowerMax(BigDecimal.valueOf((Long) attr(a, "value")), false);
                    case "DecimalMin" -> r.raiseMin(new BigDecimal((String) attr(a, "value")), Boolean.FALSE.equals(attr(a, "inclusive")));
                    case "DecimalMax" -> r.lowerMax(new BigDecimal((String) attr(a, "value")), Boolean.FALSE.equals(attr(a, "inclusive")));
                    case "Range" -> {
                        r.raiseMin(BigDecimal.valueOf((Long) attr(a, "min")), false);
                        r.lowerMax(BigDecimal.valueOf((Long) attr(a, "max")), false);
                    }
                    case "Positive" -> r.raiseMin(BigDecimal.ZERO, true);
                    case "PositiveOrZero" -> r.raiseMin(BigDecimal.ZERO, false);
                    case "Negative" -> r.lowerMax(BigDecimal.ZERO, true);
                    case "NegativeOrZero" -> r.lowerMax(BigDecimal.ZERO, false);
                    case "Digits" -> {
                        r.intDigits = min(r.intDigits, (Integer) attr(a, "integer"));
                        r.fracDigits = min(r.fracDigits, (Integer) attr(a, "fraction"));
                    }
                    case "Email" -> r.email = true;
                    case "URL" -> r.url = true;
                    case "Past" -> r.past = true;
                    case "PastOrPresent" -> { r.past = true; r.orPresent = true; }
                    case "Future" -> r.future = true;
                    case "FutureOrPresent" -> { r.future = true; r.orPresent = true; }
                    case "Pattern" -> r.pattern = (String) attr(a, "regexp");
                    case "AssertTrue" -> r.assertTrue = true;
                    case "AssertFalse" -> r.assertFalse = true;
                    default -> { }
                }
            }
            if (type == String.class) {
                // La colonna di una stringa e' lunga 255 se non dici altro.
                int column = columnLength != null ? columnLength : 255;
                if (!lob && !longText) r.maxLen = min(r.maxLen, column);
                if (r.maxLen == null) r.maxLen = 2000;
            }
            if (type.isPrimitive()) r.required = true;
            return r;
        }

        private void raiseMin(BigDecimal value, boolean exclusive) {
            if (min == null || value.compareTo(min) > 0) { min = value; minExclusive = exclusive; }
        }

        private void lowerMax(BigDecimal value, boolean exclusive) {
            if (max == null || value.compareTo(max) < 0) { max = value; maxExclusive = exclusive; }
        }
    }

    static Object attr(Annotation a, String name) {
        try {
            Method m = a.annotationType().getMethod(name);
            return m.invoke(a);
        } catch (ReflectiveOperationException e) {
            return null;
        }
    }

    private static Integer min(Integer a, Integer b) {
        if (b == null) return a;
        return a == null ? b : Math.min(a, b);
    }

    private static Integer max(Integer a, Integer b) {
        if (b == null) return a;
        return a == null ? b : Math.max(a, b);
    }

    /**
     * Un valore per un campo. {@code start} sposta il punto di partenza nelle
     * tabelle di nomi, cosi' due campi diversi non partono tutti da "Rossi";
     * {@code attempt} cambia il valore quando il precedente e' stato rifiutato.
     */
    static Object value(Class<?> type, String name, String entity, Rules r, int row, int attempt, Random rnd) {
        List<String> words = words(name);
        if (type == String.class) return string(name, words, words(entity.replaceAll("Entity$", "")), r, row, attempt, rnd);
        if (type.isEnum()) {
            Object[] constants = type.getEnumConstants();
            if (constants.length == 0) return null;
            return r.unique ? constants[(row - 1 + attempt) % constants.length] : constants[rnd.nextInt(constants.length)];
        }
        if (type == Boolean.class || type == boolean.class) {
            if (r.assertTrue) return Boolean.TRUE;
            if (r.assertFalse) return Boolean.FALSE;
            return rnd.nextBoolean();
        }
        if (type == Long.class || type == long.class) return integral(words, r, row, attempt, rnd, Long.MIN_VALUE, Long.MAX_VALUE);
        if (type == Integer.class || type == int.class) return (int) integral(words, r, row, attempt, rnd, Integer.MIN_VALUE, Integer.MAX_VALUE);
        if (type == Short.class || type == short.class) return (short) integral(words, r, row, attempt, rnd, Short.MIN_VALUE, Short.MAX_VALUE);
        if (type == Byte.class || type == byte.class) return (byte) integral(words, r, row, attempt, rnd, Byte.MIN_VALUE, Byte.MAX_VALUE);
        if (type == BigInteger.class) return BigInteger.valueOf(integral(words, r, row, attempt, rnd, Long.MIN_VALUE, Long.MAX_VALUE));
        if (type == BigDecimal.class) return decimal(words, r, row, attempt, rnd);
        if (type == Double.class || type == double.class) return decimal(words, r, row, attempt, rnd).doubleValue();
        if (type == Float.class || type == float.class) return decimal(words, r, row, attempt, rnd).floatValue();
        if (type == Character.class || type == char.class) return (char) ('A' + (row - 1 + attempt) % 26);
        if (type == UUID.class) return new UUID(rnd.nextLong(), rnd.nextLong());
        if (type == byte[].class) {
            byte[] bytes = new byte[16];
            rnd.nextBytes(bytes);
            return bytes;
        }
        if (type == Year.class) return Year.of((int) integral(List.of("anno"), r, row, attempt, rnd, 1, 9999));
        if (type == YearMonth.class) return YearMonth.from(LocalDate.now().plusDays(days(words, r, rnd)));
        if (type == Duration.class) return Duration.ofMinutes(15L * (1 + rnd.nextInt(12)));
        if (type == LocalTime.class || type == java.sql.Time.class) {
            LocalTime time = LocalTime.of(8 + rnd.nextInt(11), rnd.nextInt(4) * 15);
            return type == LocalTime.class ? time : java.sql.Time.valueOf(time);
        }
        LocalDate day = LocalDate.now().plusDays(days(words, r, rnd));
        if (type == LocalDate.class) return day;
        if (type == java.sql.Date.class) return java.sql.Date.valueOf(day);
        LocalDateTime moment = day.atTime(8 + rnd.nextInt(11), rnd.nextInt(4) * 15);
        if (type == LocalDateTime.class) return moment;
        if (type == java.sql.Timestamp.class) return java.sql.Timestamp.valueOf(moment);
        ZonedDateTime zoned = moment.atZone(ZoneId.systemDefault());
        if (type == ZonedDateTime.class) return zoned;
        if (type == OffsetDateTime.class) return zoned.toOffsetDateTime();
        if (type == Instant.class) return zoned.toInstant();
        if (type == java.util.Date.class) return java.util.Date.from(zoned.toInstant());
        return null;
    }

    // --- Stringhe ---------------------------------------------------------------

    private static String string(String name, List<String> w, List<String> entity, Rules r, int row, int attempt, Random rnd) {
        if (r.pattern != null) {
            String sample = RegexSample.generate(r.pattern, rnd);
            if (sample != null) return sample;
        }
        int start = Math.floorMod(name.hashCode(), 8);
        String v;
        boolean numbered = false;
        boolean generic = has(w, "nome", "name", "titolo", "title", "denominazione", "etichetta", "label")
                && !has(w, "cognome", "surname", "lastname", "firstname", "username", "nickname", "file");
        String[] contextual = generic ? byContext(entity) : null;
        if (contextual != null) {
            v = pick(contextual, start, row);
        } else if (r.email || has(w, "email", "mail")) {
            String nome = pick(NOMI, start, row).toLowerCase(Locale.ROOT);
            String cognome = pick(COGNOMI, start + 3, row).toLowerCase(Locale.ROOT);
            v = (nome + "." + cognome + row).replaceAll("[^a-z0-9.]", "") + "@esempio.it";
            numbered = true;
        } else if (r.url || has(w, "url", "sito", "website", "link")) {
            v = "https://www.esempio.it/pagina-" + row;
            numbered = true;
        } else if (has(w, "codicefiscale", "cf")) {
            v = RegexSample.generate("[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]", rnd);
        } else if (has(w, "partitaiva", "piva")) {
            v = RegexSample.generate("[0-9]{11}", rnd);
        } else if (has(w, "iban")) {
            v = RegexSample.generate("IT[0-9]{2}[A-Z][0-9]{22}", rnd);
        } else if (has(w, "telefono", "cellulare", "phone", "tel")) {
            v = "+39 3" + (10 + rnd.nextInt(90)) + " " + (1000000 + rnd.nextInt(9000000));
        } else if (has(w, "isbn")) {
            v = "978-88-" + (1000 + rnd.nextInt(9000)) + "-" + (100 + row) + "-" + rnd.nextInt(10);
            numbered = true;
        } else if (has(w, "cap", "zip", "postal", "postale")) {
            v = String.valueOf(10000 + rnd.nextInt(89999));
        } else if (has(w, "targa")) {
            v = RegexSample.generate("[A-Z]{2}[0-9]{3}[A-Z]{2}", rnd);
        } else if (has(w, "username", "login", "nickname")) {
            v = "utente" + row;
            numbered = true;
        } else if (has(w, "password")) {
            v = "Password" + row + "!";
            numbered = true;
        } else if (has(w, "provincia")) {
            v = pick(PROVINCE, start, row);
        } else if (has(w, "citta", "city", "comune", "localita", "luogo", "sede")) {
            v = pick(CITTA, start, row);
        } else if (has(w, "nazionalita")) {
            v = pick(NAZIONALITA, start, row);
        } else if (has(w, "nazione", "paese", "country")) {
            v = pick(NAZIONI, start, row);
        } else if (has(w, "indirizzo", "via", "address")) {
            v = pick(VIE, start, row) + " " + (1 + rnd.nextInt(120));
        } else if (has(w, "stanza", "camera", "aula", "room", "sala", "ufficio")) {
            v = String.valueOf(100 * (1 + rnd.nextInt(5)) + 1 + rnd.nextInt(20));
        } else if (has(w, "codice", "sigla", "cod", "sku", "matricola", "seriale", "serial")) {
            v = "COD-" + String.format("%03d", row);
            numbered = true;
        } else if (has(w, "titolo", "title")) {
            v = pick(TITOLI, start, row);
        } else if (has(w, "descrizione", "note", "nota", "testo", "commento", "messaggio", "motivo", "contenuto", "dettagli", "description")) {
            v = pick(DESCRIZIONI, start, row);
        } else if (has(w, "prodotto", "articolo", "item", "merce")) {
            v = pick(PRODOTTI, start, row);
        } else if (has(w, "azienda", "societa", "cliente", "fornitore", "ragionesociale", "ditta", "company", "negozio")) {
            v = pick(AZIENDE, start, row);
        } else if (has(w, "cognome", "surname", "lastname")) {
            v = pick(COGNOMI, start, row);
        } else if (w.size() == 1 && has(w, "nome") || has(w, "firstname")) {
            v = pick(NOMI, start, row);
        } else if (has(w, "nome", "utente", "referente", "responsabile", "autore", "docente", "persona", "name")) {
            v = pick(PERSONE, start, row);
        } else if (has(w, "colore", "color")) {
            v = pick(COLORI, start, row);
        } else if (has(w, "categoria", "genere", "tipo", "tipologia", "category", "type")) {
            v = pick(CATEGORIE, start, row);
        } else if (has(w, "stato", "status")) {
            v = pick(STATI, start, row);
        } else {
            v = humanize(w) + " " + row;
            numbered = true;
        }
        if (v == null) v = humanize(w) + " " + row;
        // Oltre la tabella dei nomi i valori ricomincerebbero: il numero di riga
        // li tiene diversi (una colonna unique non fa fallire niente).
        if (!numbered && (r.unique || row > 8)) v = v + " " + row;
        if (attempt > 0 && r.unique) v = v + "-" + attempt;
        return fit(v, r, row);
    }

    /** Dentro la lunghezza della colonna, senza perdere il numero che la rende unica. */
    private static String fit(String v, Rules r, int row) {
        int maxLen = r.maxLen != null ? r.maxLen : 255;
        int minLen = r.minLen != null ? r.minLen : 0;
        if (maxLen <= 0) return v;
        if (v.length() > maxLen) {
            String suffix = r.unique ? String.valueOf(row) : "";
            if (suffix.length() >= maxLen) {
                v = suffix.substring(suffix.length() - maxLen);
            } else {
                v = v.substring(0, maxLen - suffix.length()).trim() + suffix;
            }
        }
        StringBuilder sb = new StringBuilder(v);
        while (sb.length() < minLen) sb.append(sb.length() == 0 ? "x" : " x");
        return sb.length() > maxLen ? sb.substring(0, maxLen) : sb.toString();
    }

    private static String pick(String[] table, int start, int row) {
        return table[(start + row - 1) % table.length];
    }

    // --- Numeri -----------------------------------------------------------------

    private static long integral(List<String> w, Rules r, int row, int attempt, Random rnd, long typeMin, long typeMax) {
        long lo;
        long hi;
        if (has(w, "quantita", "qta", "pezzi", "scorta", "giacenza", "disponibili", "posti", "capienza", "numero", "copie", "stock", "quantity")) { lo = 1; hi = 50; }
        else if (has(w, "anno", "year")) { lo = 1960; hi = 2024; }
        else if (has(w, "eta", "age")) { lo = 18; hi = 80; }
        else if (has(w, "stelle", "rating")) { lo = 1; hi = 5; }
        else if (has(w, "voto", "valutazione", "punteggio", "score")) { lo = 1; hi = 10; }
        else if (has(w, "durata", "minuti")) { lo = 10; hi = 180; }
        else if (has(w, "prezzo", "importo", "costo", "totale", "stipendio", "salario")) { lo = 5; hi = 500; }
        else if (has(w, "sconto", "percentuale")) { lo = 0; hi = 50; }
        else if (has(w, "piano")) { lo = 0; hi = 5; }
        // Un "libroId" senza relazione punta di solito a una riga di un altro
        // servizio: gli id veri partono da 1.
        else if (!w.isEmpty() && w.get(w.size() - 1).equals("id")) { lo = 1; hi = 5; }
        else { lo = 1; hi = 1000; }

        long cMin = typeMin;
        long cMax = typeMax;
        if (r.min != null) {
            BigDecimal m = r.min.setScale(0, RoundingMode.CEILING);
            cMin = Math.max(cMin, clampToLong(m) + (r.minExclusive && m.compareTo(r.min) == 0 ? 1 : 0));
        }
        if (r.max != null) {
            BigDecimal m = r.max.setScale(0, RoundingMode.FLOOR);
            cMax = Math.min(cMax, clampToLong(m) - (r.maxExclusive && m.compareTo(r.max) == 0 ? 1 : 0));
        }
        if (r.intDigits != null && r.intDigits < 18) {
            long limit = (long) Math.pow(10, r.intDigits) - 1;
            cMin = Math.max(cMin, -limit);
            cMax = Math.min(cMax, limit);
        }
        long a = Math.max(lo, cMin);
        long b = Math.min(hi, cMax);
        if (a > b) {
            // L'intervallo "plausibile" non sta nei vincoli: valgono i vincoli.
            a = cMin;
            b = cMax;
            if (a > b) return lo;
            if (b - a > 1000) {
                if (a > Long.MIN_VALUE + 1000 && a != typeMin) b = a + 1000;
                else a = b - 1000;
            }
        }
        long span = b - a + 1;
        if (r.unique) return a + Math.floorMod(row - 1 + (long) attempt * 7, span <= 0 ? Long.MAX_VALUE : span);
        return a + (span <= 0 ? 0 : (long) (rnd.nextDouble() * span));
    }

    private static long clampToLong(BigDecimal v) {
        if (v.compareTo(BigDecimal.valueOf(Long.MAX_VALUE)) > 0) return Long.MAX_VALUE;
        if (v.compareTo(BigDecimal.valueOf(Long.MIN_VALUE)) < 0) return Long.MIN_VALUE;
        return v.longValue();
    }

    private static BigDecimal decimal(List<String> w, Rules r, int row, int attempt, Random rnd) {
        double lo;
        double hi;
        if (has(w, "prezzo", "importo", "costo", "totale", "stipendio", "salario", "price", "amount")) { lo = 5; hi = 500; }
        else if (has(w, "peso", "kg", "weight")) { lo = 0.5; hi = 50; }
        else if (has(w, "sconto", "percentuale")) { lo = 0; hi = 50; }
        else if (has(w, "lat", "latitudine")) { lo = 36; hi = 47; }
        else if (has(w, "lon", "lng", "longitudine")) { lo = 6; hi = 18; }
        else if (has(w, "temperatura")) { lo = -5; hi = 35; }
        else if (has(w, "voto", "valutazione", "media")) { lo = 1; hi = 10; }
        else { lo = 1; hi = 1000; }
        int scale = r.fracDigits != null ? r.fracDigits : 2;
        double step = Math.pow(10, -scale);
        double cMin = -1e15;
        double cMax = 1e15;
        if (r.min != null) cMin = r.min.doubleValue() + (r.minExclusive ? step : 0);
        if (r.max != null) cMax = r.max.doubleValue() - (r.maxExclusive ? step : 0);
        if (r.intDigits != null) {
            double limit = Math.pow(10, r.intDigits) - step;
            cMin = Math.max(cMin, -limit);
            cMax = Math.min(cMax, limit);
        }
        double a = Math.max(lo, cMin);
        double b = Math.min(hi, cMax);
        if (a > b) {
            a = cMin;
            b = Math.min(cMax, cMin + 1000);
            if (a > b) b = a;
        }
        double v = r.unique ? a + ((row - 1 + attempt * 7) * step * 10) % Math.max(b - a, step) : a + rnd.nextDouble() * (b - a);
        BigDecimal result = BigDecimal.valueOf(v).setScale(scale, RoundingMode.HALF_UP);
        // L'arrotondamento non deve portarlo fuori dall'intervallo.
        if (result.doubleValue() > b) result = BigDecimal.valueOf(b).setScale(scale, RoundingMode.FLOOR);
        if (result.doubleValue() < a) result = BigDecimal.valueOf(a).setScale(scale, RoundingMode.CEILING);
        return result;
    }

    // --- Date -------------------------------------------------------------------

    /**
     * Quanti giorni da oggi. Gli inizi (data ordine, iscrizione, prestito)
     * stanno nel passato, le fini (scadenza, consegna, restituzione) fra dieci
     * giorni fa e fra venti: cosi' una fine viene sempre dopo il suo inizio, e
     * qualche scadenza e' gia' passata (i ritardi si vedono).
     */
    private static long days(List<String> w, Rules r, Random rnd) {
        long d;
        if (has(w, "nascita", "birth", "compleanno")) d = -(365L * (18 + rnd.nextInt(60)) + rnd.nextInt(365));
        else if (has(w, "fine", "end", "scadenza", "termine", "consegna", "restituzione", "ritorno", "chiusura", "checkout", "al")) d = -9 + rnd.nextInt(30);
        else if (has(w, "inizio", "start", "apertura", "partenza", "checkin", "emissione", "ordine", "creazione", "registrazione", "iscrizione", "prestito", "acquisto", "assunzione", "dal")) d = -(10 + rnd.nextInt(60));
        else d = -(1 + rnd.nextInt(365));
        if (r.future && (d < 0 || d == 0 && !r.orPresent)) d = 1 + rnd.nextInt(60);
        if (r.past && (d > 0 || d == 0 && !r.orPresent)) d = -(1 + rnd.nextInt(365));
        return d;
    }

    // --- Nomi dei campi ---------------------------------------------------------

    /** "annoIscrizione" e "anno_iscrizione" diventano [anno, iscrizione]. */
    static List<String> words(String name) {
        List<String> out = new ArrayList<>();
        for (String part : name.replaceAll("([a-z0-9])([A-Z])", "$1 $2").split("[^A-Za-z0-9]+")) {
            if (!part.isEmpty()) out.add(part.toLowerCase(Locale.ROOT));
        }
        return out;
    }

    /**
     * Le chiavi corte (via, cod, tel, eta) valgono solo come parola intera:
     * "viaggio" non e' un indirizzo. Quelle lunghe anche dentro il nome.
     */
    static boolean has(List<String> words, String... keys) {
        String joined = String.join("", words);
        for (String key : keys) {
            if (key.length() <= 4) {
                if (words.contains(key)) return true;
            } else if (joined.contains(key)) {
                return true;
            }
        }
        return false;
    }

    private static String humanize(List<String> w) {
        if (w.isEmpty()) return "Valore";
        String s = String.join(" ", w);
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }
}
