package devdata;

import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.metamodel.Attribute;
import jakarta.persistence.metamodel.EmbeddableType;
import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.IdentifiableType;
import jakarta.persistence.metamodel.ManagedType;
import jakarta.persistence.metamodel.PluralAttribute;
import jakarta.persistence.metamodel.SingularAttribute;

import javax.sql.DataSource;
import java.lang.annotation.Annotation;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Lo schema della base dati in markdown, per l'allegato tecnico.
 *
 * Il modello concettuale viene dalle classi @Entity come le vede Hibernate
 * (entita', attributi, relazioni con la loro cardinalita'). Il modello logico
 * viene dal database vero, interrogato con JDBC dopo che Hibernate ha creato
 * le tabelle: nomi, tipi, chiavi primarie ed esterne, vincoli di unicita' e
 * di valore sono quelli che ci sono davvero, non quelli che ci si aspetta.
 */
final class SchemaWriter {

    private final EntityManagerFactory emf;
    private final DataSource dataSource;

    SchemaWriter(EntityManagerFactory emf, DataSource dataSource) {
        this.emf = emf;
        this.dataSource = dataSource;
    }

    String write() throws SQLException {
        List<EntityType<?>> entities = new ArrayList<>(emf.getMetamodel().getEntities());
        entities.sort(Comparator.comparing(EntityType::getName));
        StringBuilder out = new StringBuilder();
        if (entities.isEmpty()) {
            out.append("Nessuna classe `@Entity` in questo modulo.\n");
            return out.toString();
        }
        List<Table> tables = readDatabase(entities);
        conceptual(out, entities, tables);
        logical(out, tables);
        return out.toString();
    }

    // =========================================================================
    // Modello concettuale: dalle entity
    // =========================================================================

    private void conceptual(StringBuilder out, List<EntityType<?>> entities, List<Table> tables) {
        out.append("### Modello concettuale\n\n");
        out.append("Le entita' e le loro relazioni, come le vede Hibernate.\n\n");
        for (EntityType<?> e : entities) {
            List<String> attributes = new ArrayList<>();
            Set<String> inherited = new LinkedHashSet<>();
            IdentifiableType<?> parent = e.getSupertype();
            while (parent != null && !(parent instanceof EntityType<?>)) parent = parent.getSupertype();
            if (parent != null) for (Attribute<?, ?> a : parent.getAttributes()) inherited.add(a.getName());
            for (Attribute<?, ?> a : Seeder.sorted(e.getAttributes(), e.getJavaType())) {
                if (inherited.contains(a.getName()) || a.isAssociation()) continue;
                attributes.add(describeAttribute(a));
            }
            StringBuilder line = new StringBuilder("- **").append(display(e.getJavaType())).append("**");
            if (!attributes.isEmpty()) line.append(" (").append(String.join(", ", attributes)).append(")");
            List<String> notes = new ArrayList<>();
            if (Modifier.isAbstract(e.getJavaType().getModifiers())) notes.add("astratta");
            if (parent != null) notes.add("e' un tipo di **" + display(parent.getJavaType()) + "**");
            notes.add("classe `" + e.getJavaType().getSimpleName() + "`");
            Table t = tableOf(e, tables);
            if (t != null) notes.add("tabella `" + t.name + "`");
            line.append(" -- ").append(String.join(", ", notes));
            out.append(line).append('\n');
        }
        out.append('\n');

        List<String> relations = relations(entities);
        if (!relations.isEmpty()) {
            out.append("**Relazioni**\n\n");
            for (String r : relations) out.append("- ").append(r).append('\n');
            out.append('\n');
        }
    }

    private String describeAttribute(Attribute<?, ?> a) {
        String name = a.getName();
        if (a instanceof SingularAttribute<?, ?> s && s.isId()) return name + " (identificatore)";
        Class<?> type = a.getJavaType();
        if (type.isEnum()) {
            return name + " (" + Arrays.stream(type.getEnumConstants()).map(Object::toString).collect(Collectors.joining(" | ")) + ")";
        }
        if (a.getPersistentAttributeType() == Attribute.PersistentAttributeType.EMBEDDED) {
            EmbeddableType<?> et = emf.getMetamodel().embeddable(type);
            return name + " (" + Seeder.sorted(et.getAttributes(), type).stream().map(Attribute::getName).collect(Collectors.joining(", ")) + ")";
        }
        if (a.getPersistentAttributeType() == Attribute.PersistentAttributeType.ELEMENT_COLLECTION) {
            return name + " (elenco di valori)";
        }
        return name;
    }

    private List<String> relations(List<EntityType<?>> entities) {
        // Prima gli "altri lati" (mappedBy): servono a dire che una relazione e'
        // percorribile in tutti e due i versi.
        Map<String, String> inverse = new LinkedHashMap<>();
        for (EntityType<?> e : entities) {
            for (Attribute<?, ?> a : e.getAttributes()) {
                if (!a.isAssociation()) continue;
                String mappedBy = Seeder.mappedBy(annotations(e, a));
                if (!mappedBy.isEmpty()) inverse.put(target(a).getName() + "#" + mappedBy, display(e.getJavaType()) + "." + a.getName());
            }
        }
        List<String> out = new ArrayList<>();
        for (EntityType<?> e : entities) {
            for (Attribute<?, ?> a : Seeder.sorted(e.getAttributes(), e.getJavaType())) {
                if (a.getDeclaringType() != e && a.getDeclaringType() instanceof EntityType<?>) continue;
                List<Annotation> ann = annotations(e, a);
                String from = "**" + display(e.getJavaType()) + "**";
                if (a.getPersistentAttributeType() == Attribute.PersistentAttributeType.ELEMENT_COLLECTION) {
                    out.add(from + " ha un elenco di valori `" + a.getName() + "` (in una tabella a parte)");
                    continue;
                }
                if (!a.isAssociation() || !Seeder.mappedBy(ann).isEmpty()) continue;
                String to = "**" + display(target(a)) + "**";
                String kind;
                String arrow = " -> ";
                switch (a.getPersistentAttributeType()) {
                    case MANY_TO_ONE -> kind = "molti a uno";
                    case ONE_TO_ONE -> kind = "uno a uno";
                    case ONE_TO_MANY -> kind = "uno a molti";
                    default -> { kind = "molti a molti"; arrow = " <-> "; }
                }
                StringBuilder r = new StringBuilder(from).append(arrow).append(to).append(": ").append(kind);
                if (a instanceof SingularAttribute<?, ?> s) r.append(s.isOptional() && !Seeder.has(ann, "MapsId") ? ", facoltativa" : ", obbligatoria");
                r.append(" (campo `").append(a.getName()).append("`");
                String back = inverse.get(e.getJavaType().getName() + "#" + a.getName());
                if (back != null) r.append("; dall'altra parte `").append(back).append("`");
                r.append(")");
                out.add(r.toString());
            }
        }
        return out;
    }

    private static Class<?> target(Attribute<?, ?> a) {
        return a instanceof PluralAttribute<?, ?, ?> p ? p.getElementType().getJavaType() : a.getJavaType();
    }

    private static List<Annotation> annotations(ManagedType<?> type, Attribute<?, ?> a) {
        return Seeder.annotations(Seeder.findField(type.getJavaType(), a.getName()), a.getJavaMember());
    }

    static String display(Class<?> type) {
        String n = type.getSimpleName();
        return n.endsWith("Entity") && n.length() > 6 ? n.substring(0, n.length() - 6) : n;
    }

    // =========================================================================
    // Modello logico: dal database
    // =========================================================================

    static final class Column {
        String name;
        String type;
        boolean nullable;
        boolean identity;
        boolean pk;
        boolean unique;
        String fkTable;
        String fkColumn;
        int order = Integer.MAX_VALUE;
        int position;
        final List<String> notes = new ArrayList<>();
    }

    static final class Table {
        String name;
        String raw;
        final List<Column> columns = new ArrayList<>();
        final List<String> notes = new ArrayList<>();
        final List<String> owners = new ArrayList<>();

        Column column(String n) {
            for (Column c : columns) if (c.name.equalsIgnoreCase(n)) return c;
            return null;
        }
    }

    /** Quello che le entity dicono di una colonna, per completare il database. */
    private record AttributeInfo(Class<?> javaType, boolean ordinal, int length, String generation, int order) {
    }

    List<Table> readDatabase(List<EntityType<?>> entities) throws SQLException {
        List<Table> tables = new ArrayList<>();
        try (Connection c = dataSource.getConnection()) {
            DatabaseMetaData md = c.getMetaData();
            String catalog = c.getCatalog();
            String schema = c.getSchema();
            boolean upper = md.storesUpperCaseIdentifiers();
            try (ResultSet rs = md.getTables(catalog, schema, "%", null)) {
                while (rs.next()) {
                    String kind = String.valueOf(rs.getString("TABLE_TYPE")).toUpperCase(Locale.ROOT);
                    if (!kind.equals("TABLE") && !kind.equals("BASE TABLE")) continue;
                    String raw = rs.getString("TABLE_NAME");
                    String lower = raw.toLowerCase(Locale.ROOT);
                    if (lower.startsWith("hibernate_sequence") || lower.startsWith("flyway_")) continue;
                    Table t = new Table();
                    t.raw = raw;
                    t.name = upper ? lower : raw;
                    tables.add(t);
                }
            }
            tables.sort(Comparator.comparing(t -> t.name));
            Map<String, Map<String, AttributeInfo>> info = attributeInfo(entities);
            for (Table t : tables) {
                readColumns(md, catalog, schema, t, upper);
                readChecks(c, schema, t);
                Map<String, AttributeInfo> byColumn = info.getOrDefault(t.name.toLowerCase(Locale.ROOT), Map.of());
                for (Column col : t.columns) describeColumn(col, byColumn.get(col.name.toLowerCase(Locale.ROOT)));
                // Hibernate 7 mette le colonne in ordine di tipo, non di
                // dichiarazione: per leggerle, prima la chiave, poi i campi come
                // sono scritti nella classe, in fondo le chiavi esterne.
                t.columns.sort(Comparator.comparingInt((Column col) -> col.pk ? 0 : col.fkTable != null ? 2 : col.order != Integer.MAX_VALUE ? 1 : 3)
                        .thenComparingInt(col -> col.order)
                        .thenComparingInt(col -> col.position));
            }
        }
        for (EntityType<?> e : entities) {
            Table t = tableOf(e, tables);
            if (t != null) t.owners.add(e.getJavaType().getSimpleName());
        }
        return tables;
    }

    private void readColumns(DatabaseMetaData md, String catalog, String schema, Table t, boolean upper) throws SQLException {
        try (ResultSet rs = md.getColumns(catalog, schema, t.raw, "%")) {
            List<Object[]> rows = new ArrayList<>();
            while (rs.next()) {
                Column col = new Column();
                col.name = upper ? rs.getString("COLUMN_NAME").toLowerCase(Locale.ROOT) : rs.getString("COLUMN_NAME");
                col.type = sqlType(rs.getString("TYPE_NAME"), rs.getInt("COLUMN_SIZE"), rs.getInt("DECIMAL_DIGITS"));
                col.nullable = "YES".equalsIgnoreCase(rs.getString("IS_NULLABLE"));
                col.identity = "YES".equalsIgnoreCase(rs.getString("IS_AUTOINCREMENT"));
                rows.add(new Object[]{rs.getInt("ORDINAL_POSITION"), col});
            }
            rows.sort(Comparator.comparingInt(r -> (Integer) r[0]));
            for (Object[] r : rows) {
                Column col = (Column) r[1];
                col.position = t.columns.size();
                t.columns.add(col);
            }
        }
        List<String> pk = new ArrayList<>();
        try (ResultSet rs = md.getPrimaryKeys(catalog, schema, t.raw)) {
            Map<Integer, String> ordered = new TreeMap<>();
            while (rs.next()) ordered.put(rs.getInt("KEY_SEQ"), rs.getString("COLUMN_NAME"));
            pk.addAll(ordered.values());
        }
        for (String p : pk) {
            Column col = t.column(p);
            if (col != null) col.pk = true;
        }
        if (pk.size() > 1) t.notes.add("Chiave primaria composta: (" + pk.stream().map(s -> "`" + name(s, upper) + "`").collect(Collectors.joining(", ")) + ").");
        try (ResultSet rs = md.getImportedKeys(catalog, schema, t.raw)) {
            while (rs.next()) {
                Column col = t.column(rs.getString("FKCOLUMN_NAME"));
                if (col == null) continue;
                col.fkTable = name(rs.getString("PKTABLE_NAME"), upper);
                col.fkColumn = name(rs.getString("PKCOLUMN_NAME"), upper);
            }
        }
        Map<String, List<String>> uniques = new TreeMap<>();
        try (ResultSet rs = md.getIndexInfo(catalog, schema, t.raw, true, false)) {
            while (rs.next()) {
                if (rs.getBoolean("NON_UNIQUE") || rs.getString("COLUMN_NAME") == null) continue;
                uniques.computeIfAbsent(rs.getString("INDEX_NAME"), k -> new ArrayList<>()).add(rs.getString("COLUMN_NAME"));
            }
        }
        Set<String> pkSet = pk.stream().map(s -> s.toLowerCase(Locale.ROOT)).collect(Collectors.toSet());
        for (List<String> cols : uniques.values()) {
            Set<String> set = cols.stream().map(s -> s.toLowerCase(Locale.ROOT)).collect(Collectors.toSet());
            if (set.equals(pkSet)) continue;
            if (cols.size() == 1) {
                Column col = t.column(cols.get(0));
                if (col != null) col.unique = true;
            } else {
                t.notes.add("Univoche insieme: (" + cols.stream().map(s -> "`" + name(s, upper) + "`").collect(Collectors.joining(", ")) + ").");
            }
        }
    }

    private static String name(String raw, boolean upper) {
        return upper ? raw.toLowerCase(Locale.ROOT) : raw;
    }

    /** Quante righe ha ogni tabella: "articoli 5, deposito_entity 5". */
    static String counts(DataSource dataSource) throws SQLException {
        List<String> out = new ArrayList<>();
        try (Connection c = dataSource.getConnection()) {
            DatabaseMetaData md = c.getMetaData();
            boolean upper = md.storesUpperCaseIdentifiers();
            String quote = md.getIdentifierQuoteString().trim();
            List<String> names = new ArrayList<>();
            try (ResultSet rs = md.getTables(c.getCatalog(), c.getSchema(), "%", null)) {
                while (rs.next()) {
                    String kind = String.valueOf(rs.getString("TABLE_TYPE")).toUpperCase(Locale.ROOT);
                    String raw = rs.getString("TABLE_NAME");
                    if ((kind.equals("TABLE") || kind.equals("BASE TABLE")) && !raw.toLowerCase(Locale.ROOT).startsWith("hibernate_sequence")) names.add(raw);
                }
            }
            names.sort(Comparator.comparing(n -> n.toLowerCase(Locale.ROOT)));
            for (String raw : names) {
                try (PreparedStatement ps = c.prepareStatement("select count(*) from " + quote + raw + quote);
                     ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) out.add(name(raw, upper) + " " + rs.getLong(1));
                }
            }
        }
        return String.join(", ", out);
    }

    /** I vincoli CHECK (valori di un enum, @Min/@Max...), dall'information_schema. */
    private void readChecks(Connection c, String schema, Table t) {
        String sql = "select ccu.column_name, cc.check_clause"
                + " from information_schema.check_constraints cc"
                + " join information_schema.constraint_column_usage ccu"
                + " on cc.constraint_name = ccu.constraint_name and cc.constraint_schema = ccu.constraint_schema"
                + " where ccu.table_name = ? and ccu.table_schema = ?";
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, t.raw);
            ps.setString(2, schema);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Column col = t.column(rs.getString(1));
                    String clause = rs.getString(2);
                    if (col == null || clause == null) continue;
                    String note = describeCheck(clause);
                    if (note != null && !col.notes.contains(note)) col.notes.add(note);
                }
            }
        } catch (SQLException e) {
            // Un database senza information_schema: i CHECK restano fuori.
        }
    }

    private static String describeCheck(String clause) {
        Matcher between = Pattern.compile("(?i)between\\s+(-?[\\d.]+)\\s+and\\s+(-?[\\d.]+)").matcher(clause);
        if (between.find()) return "da " + between.group(1) + " a " + between.group(2);
        List<String> quoted = new ArrayList<>();
        Matcher q = Pattern.compile("'([^']*)'").matcher(clause);
        while (q.find()) quoted.add(q.group(1));
        if (quoted.size() > 1 || clause.toUpperCase(Locale.ROOT).contains(" IN ")) {
            if (!quoted.isEmpty()) return "valori ammessi: " + String.join(", ", quoted);
        }
        String low = null;
        String high = null;
        Matcher cmp = Pattern.compile("(>=|<=|>|<)\\s*(-?[\\d.]+)").matcher(clause);
        while (cmp.find()) {
            switch (cmp.group(1)) {
                case ">=" -> low = cmp.group(2);
                case ">" -> low = "piu' di " + cmp.group(2);
                case "<=" -> high = cmp.group(2);
                default -> high = "meno di " + cmp.group(2);
            }
        }
        if (low != null && high != null && !low.startsWith("p") && !high.startsWith("m")) return "da " + low + " a " + high;
        List<String> bounds = new ArrayList<>();
        if (low != null) bounds.add(low.startsWith("p") ? low : "almeno " + low);
        if (high != null) bounds.add(high.startsWith("m") ? high : "al massimo " + high);
        return bounds.isEmpty() ? null : String.join(", ", bounds);
    }

    private void describeColumn(Column col, AttributeInfo info) {
        if (col.identity) col.notes.add(0, "generato dal database (identity)");
        if (col.name.equalsIgnoreCase("dtype")) col.notes.add(0, "di che classe e' la riga (ereditarieta')");
        if (info == null) return;
        col.order = info.order();
        if (info.javaType().isEnum()) {
            String values = Arrays.stream(info.javaType().getEnumConstants()).map(Object::toString).collect(Collectors.joining(", "));
            if (info.ordinal()) {
                col.notes.removeIf(n -> n.startsWith("da "));
                col.notes.add("enum salvato come numero: 0 = " + String.join(", ", numbered(info.javaType())));
            } else {
                // H2 ha un tipo ENUM suo; su PostgreSQL e' un VARCHAR con un CHECK:
                // lo scriviamo come lo troverai li'.
                if (col.type.equals("ENUM")) col.type = "VARCHAR(" + info.length() + ")";
                col.notes.removeIf(n -> n.startsWith("valori ammessi"));
                col.notes.add("valori ammessi: " + values);
            }
        }
        if (info.generation() != null && !col.identity) col.notes.add(0, info.generation());
    }

    private static List<String> numbered(Class<?> enumType) {
        List<String> out = new ArrayList<>();
        Object[] constants = enumType.getEnumConstants();
        for (int i = 0; i < constants.length; i++) out.add((i == 0 ? "" : i + " = ") + constants[i]);
        return out;
    }

    static String sqlType(String typeName, int size, int digits) {
        String t = typeName == null ? "" : typeName.toUpperCase(Locale.ROOT);
        // H2 scrive i valori dentro il tipo: ENUM('A', 'B').
        if (t.startsWith("ENUM")) return "ENUM";
        switch (t) {
            case "CHARACTER VARYING", "VARCHAR", "VARCHAR2", "NVARCHAR", "VARCHAR_IGNORECASE":
                return "VARCHAR(" + size + ")";
            case "CHARACTER", "CHAR", "BPCHAR", "NCHAR":
                return "CHAR(" + size + ")";
            case "CHARACTER LARGE OBJECT", "CLOB", "TEXT":
                return "TEXT";
            case "BINARY VARYING", "VARBINARY", "BINARY LARGE OBJECT", "BLOB", "BYTEA", "BINARY", "OID":
                return "BYTEA";
            case "NUMERIC", "DECIMAL":
                return "NUMERIC(" + size + "," + digits + ")";
            case "DECFLOAT":
                return "NUMERIC";
            case "TINYINT", "INT2", "SMALLINT", "SMALLSERIAL":
                return "SMALLINT";
            case "INT", "INT4", "INTEGER", "SERIAL":
                return "INTEGER";
            case "INT8", "BIGINT", "BIGSERIAL":
                return "BIGINT";
            case "FLOAT8", "DOUBLE", "DOUBLE PRECISION", "FLOAT":
                return "DOUBLE PRECISION";
            case "FLOAT4", "REAL":
                return "REAL";
            case "BOOL", "BOOLEAN", "BIT":
                return "BOOLEAN";
            case "TIMESTAMP", "TIMESTAMP WITHOUT TIME ZONE":
                return "TIMESTAMP";
            case "TIMESTAMPTZ", "TIMESTAMP WITH TIME ZONE":
                return "TIMESTAMP WITH TIME ZONE";
            case "TIME", "TIME WITHOUT TIME ZONE":
                return "TIME";
            case "TIMETZ", "TIME WITH TIME ZONE":
                return "TIME WITH TIME ZONE";
            default:
                return t;
        }
    }

    /**
     * Per ogni tabella, le colonne che corrispondono ad attributi delle entity
     * (i nomi li calcola la stessa regola di Hibernate: nomeCampo -> nome_campo).
     */
    private Map<String, Map<String, AttributeInfo>> attributeInfo(List<EntityType<?>> entities) {
        Map<String, Map<String, AttributeInfo>> out = new LinkedHashMap<>();
        for (EntityType<?> e : entities) {
            for (String table : tableCandidates(e)) {
                Map<String, AttributeInfo> columns = out.computeIfAbsent(table, k -> new LinkedHashMap<>());
                collectColumns(e, e.getJavaType(), columns, 0);
            }
        }
        return out;
    }

    private void collectColumns(ManagedType<?> type, Class<?> javaType, Map<String, AttributeInfo> columns, int depth) {
        for (Attribute<?, ?> a : Seeder.sorted(type.getAttributes(), javaType)) {
            Field field = Seeder.findField(javaType, a.getName());
            List<Annotation> ann = Seeder.annotations(field, a.getJavaMember());
            if (a.getPersistentAttributeType() == Attribute.PersistentAttributeType.EMBEDDED && depth < 3) {
                collectColumns(emf.getMetamodel().embeddable(a.getJavaType()), a.getJavaType(), columns, depth + 1);
                continue;
            }
            if (a.getPersistentAttributeType() != Attribute.PersistentAttributeType.BASIC) continue;
            String column = physical(a.getName());
            Annotation col = Seeder.find(ann, "Column");
            int length = 255;
            if (col != null) {
                if (Values.attr(col, "name") instanceof String n && !n.isEmpty()) column = n;
                if (Values.attr(col, "length") instanceof Integer l) length = l;
            }
            boolean ordinal = false;
            Annotation enumerated = Seeder.find(ann, "Enumerated");
            if (a.getJavaType().isEnum()) {
                ordinal = enumerated == null || String.valueOf(Values.attr(enumerated, "value")).equals("ORDINAL");
            }
            String generation = null;
            Annotation generated = Seeder.find(ann, "GeneratedValue");
            if (generated != null) {
                String strategy = String.valueOf(Values.attr(generated, "strategy"));
                if (strategy.equals("IDENTITY")) generation = "generato dal database (identity)";
                else if (strategy.equals("UUID")) generation = "UUID generato da Hibernate";
                else generation = "generato da Hibernate con una sequenza";
            } else if (Seeder.has(ann, "UuidGenerator")) {
                generation = "UUID generato da Hibernate";
            } else if (a instanceof SingularAttribute<?, ?> s && s.isVersion()) {
                generation = "versione della riga (@Version): la aggiorna Hibernate";
            }
            columns.putIfAbsent(column.toLowerCase(Locale.ROOT), new AttributeInfo(a.getJavaType(), ordinal, length, generation, columns.size()));
        }
    }

    /** I nomi che la tabella di un'entity potrebbe avere, dal piu' probabile. */
    private static List<String> tableCandidates(EntityType<?> e) {
        List<String> out = new ArrayList<>();
        for (Class<?> c = e.getJavaType(); c != null && c != Object.class; c = c.getSuperclass()) {
            Annotation table = null;
            boolean entity = false;
            for (Annotation a : c.getAnnotations()) {
                String n = a.annotationType().getSimpleName();
                if (n.equals("Table")) table = a;
                if (n.equals("Entity")) entity = true;
            }
            if (!entity) continue;
            if (table != null && Values.attr(table, "name") instanceof String n && !n.isEmpty()) {
                out.add(n.toLowerCase(Locale.ROOT));
            } else {
                String entityName = c.getSimpleName();
                for (Annotation a : c.getAnnotations()) {
                    if (a.annotationType().getSimpleName().equals("Entity") && Values.attr(a, "name") instanceof String n && !n.isEmpty()) entityName = n;
                }
                out.add(physical(entityName));
            }
        }
        return out;
    }

    private static Table tableOf(EntityType<?> e, List<Table> tables) {
        for (String candidate : tableCandidates(e)) {
            for (Table t : tables) if (t.name.equalsIgnoreCase(candidate)) return t;
        }
        return null;
    }

    /** La regola di Spring Boot e Hibernate (CamelCaseToUnderscoresNamingStrategy). */
    static String physical(String name) {
        StringBuilder b = new StringBuilder(name.replace('.', '_'));
        for (int i = 1; i < b.length() - 1; i++) {
            char before = b.charAt(i - 1);
            char current = b.charAt(i);
            char after = b.charAt(i + 1);
            if ((Character.isLowerCase(before) || Character.isDigit(before)) && Character.isUpperCase(current)
                    && (Character.isLowerCase(after) || Character.isDigit(after))) {
                b.insert(i++, '_');
            }
        }
        return b.toString().toLowerCase(Locale.ROOT);
    }

    // =========================================================================
    // Scrittura del modello logico
    // =========================================================================

    private void logical(StringBuilder out, List<Table> tables) {
        out.append("### Modello logico\n\n");
        out.append("Tabelle, colonne e vincoli letti dal database dopo che Hibernate le ha create.\n\n");
        out.append("```mermaid\nerDiagram\n");
        for (Table t : tables) {
            out.append("    ").append(entityId(t.name)).append(" {\n");
            for (Column c : t.columns) {
                List<String> keys = new ArrayList<>();
                if (c.pk) keys.add("PK");
                if (c.fkTable != null) keys.add("FK");
                if (c.unique && !c.pk) keys.add("UK");
                out.append("        ").append(mermaidType(c.type)).append(' ').append(c.name);
                if (!keys.isEmpty()) out.append(' ').append(String.join(", ", keys));
                out.append('\n');
            }
            out.append("    }\n");
        }
        for (Table t : tables) {
            for (Column c : t.columns) {
                if (c.fkTable == null) continue;
                String parent = c.nullable ? "|o" : "||";
                String child = c.unique || c.pk && t.columns.stream().filter(x -> x.pk).count() == 1 ? "o|" : "o{";
                out.append("    ").append(entityId(c.fkTable)).append(' ').append(parent).append("--").append(child)
                        .append(' ').append(entityId(t.name)).append(" : \"").append(c.name).append("\"\n");
            }
        }
        out.append("```\n\n");

        for (Table t : tables) {
            out.append("#### Tabella `").append(t.name).append("`\n\n");
            out.append(ownerNote(t)).append("\n\n");
            for (String n : t.notes) out.append(n).append("\n\n");
            out.append("| Colonna | Tipo | Chiave | Null | Note |\n");
            out.append("| :--- | :--- | :---: | :---: | :--- |\n");
            for (Column c : t.columns) {
                List<String> keys = new ArrayList<>();
                if (c.pk) keys.add("PK");
                if (c.fkTable != null) keys.add("FK");
                List<String> notes = new ArrayList<>(c.notes);
                if (c.fkTable != null) notes.add(0, "riferimento a `" + c.fkTable + "`(`" + c.fkColumn + "`)");
                if (c.unique && !c.pk) notes.add("univoco");
                out.append("| `").append(c.name).append("` | ").append(c.type).append(" | ").append(String.join(", ", keys))
                        .append(" | ").append(c.nullable ? "si" : "no").append(" | ").append(String.join("; ", notes)).append(" |\n");
            }
            out.append('\n');
        }
    }

    private static String ownerNote(Table t) {
        if (t.owners.size() == 1) return "Classe `" + t.owners.get(0) + "`.";
        if (t.owners.size() > 1) {
            return "Classi " + t.owners.stream().map(o -> "`" + o + "`").collect(Collectors.joining(", "))
                    + " (una sola tabella per tutta la gerarchia).";
        }
        long fks = t.columns.stream().filter(c -> c.fkTable != null).count();
        if (fks >= 2) return "Tabella di collegamento di una relazione molti a molti: la crea Hibernate.";
        if (fks == 1) return "Valori di un elenco (@ElementCollection) o di una relazione uno a molti: la crea Hibernate.";
        return "Nessuna classe la dichiara: la crea Hibernate.";
    }

    private static String entityId(String table) {
        return table.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9_]", "_");
    }

    private static String mermaidType(String sqlType) {
        return sqlType.toLowerCase(Locale.ROOT).replaceAll("\\(.*\\)", "").trim().replace(' ', '_');
    }
}
