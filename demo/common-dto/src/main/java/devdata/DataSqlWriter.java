package devdata;

import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.metamodel.EntityType;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Le righe generate da {@link Seeder}, come <code>INSERT</code> SQL semplici
 * (senza sintassi di un motore in particolare), da mettere in un data.sql
 * vero e proprio.
 *
 * Legge lo stesso database di {@link SchemaWriter} (con JDBC, dopo che
 * Hibernate ha creato le tabelle e Seeder le ha riempite), non gli oggetti
 * Java: cosi' il valore scritto e' quello davvero salvato, qualunque cosa lo
 * abbia generato. Le tabelle si scrivono in un ordine che rispetta le chiavi
 * esterne, cosi' lo script gira senza errori dalla prima all'ultima riga.
 */
final class DataSqlWriter {

    private final EntityManagerFactory emf;
    private final DataSource dataSource;

    DataSqlWriter(EntityManagerFactory emf, DataSource dataSource) {
        this.emf = emf;
        this.dataSource = dataSource;
    }

    String write() throws SQLException {
        List<EntityType<?>> entities = new ArrayList<>(emf.getMetamodel().getEntities());
        entities.sort(Comparator.comparing(EntityType::getName));
        List<SchemaWriter.Table> tables = new SchemaWriter(emf, dataSource).readDatabase(entities);
        List<SchemaWriter.Table> ordered = byDependency(tables);

        StringBuilder out = new StringBuilder();
        try (Connection c = dataSource.getConnection()) {
            for (SchemaWriter.Table t : ordered) {
                writeTable(c, t, out);
            }
        }
        return out.toString();
    }

    /**
     * Prima le tabelle a cui le altre puntano (Hibernate le crea in questo
     * stesso ordine, per lo stesso motivo): altrimenti un INSERT con una
     * chiave esterna arriverebbe prima della riga a cui punta.
     */
    private static List<SchemaWriter.Table> byDependency(List<SchemaWriter.Table> tables) {
        List<SchemaWriter.Table> out = new ArrayList<>();
        Set<String> placed = new LinkedHashSet<>();
        Set<String> visiting = new LinkedHashSet<>();
        for (SchemaWriter.Table t : tables) visit(t, tables, placed, visiting, out);
        return out;
    }

    private static void visit(SchemaWriter.Table t, List<SchemaWriter.Table> all, Set<String> placed, Set<String> visiting, List<SchemaWriter.Table> out) {
        String key = t.name.toLowerCase(Locale.ROOT);
        if (placed.contains(key) || visiting.contains(key)) return;
        visiting.add(key);
        for (SchemaWriter.Column col : t.columns) {
            if (col.fkTable == null || col.fkTable.equalsIgnoreCase(t.name)) continue;
            for (SchemaWriter.Table other : all) {
                if (other.name.equalsIgnoreCase(col.fkTable)) visit(other, all, placed, visiting, out);
            }
        }
        visiting.remove(key);
        if (placed.add(key)) out.add(t);
    }

    private void writeTable(Connection c, SchemaWriter.Table t, StringBuilder out) throws SQLException {
        // t.raw e' il nome esatto restituito da getTables(): senza virgolette
        // intorno, cosi' com'e', lo risolve il motore che l'ha appena dato.
        // Niente ORDER BY su una colonna per nome: qui basta SELECT *, e le
        // tabelle sono gia' nell'ordine giusto (byDependency).
        String sql = "SELECT * FROM " + t.raw;
        boolean any = false;
        try (PreparedStatement ps = c.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            ResultSetMetaData md = rs.getMetaData();
            int[] resultIndex = new int[t.columns.size()];
            for (int i = 0; i < t.columns.size(); i++) {
                resultIndex[i] = columnIndex(md, t.columns.get(i).name);
            }
            while (rs.next()) {
                if (!any) {
                    out.append("-- ").append(t.name).append('\n');
                    any = true;
                }
                StringBuilder cols = new StringBuilder();
                StringBuilder vals = new StringBuilder();
                boolean first = true;
                for (int i = 0; i < t.columns.size(); i++) {
                    if (resultIndex[i] < 1) continue;
                    if (!first) { cols.append(", "); vals.append(", "); }
                    first = false;
                    cols.append(t.columns.get(i).name);
                    vals.append(formatValue(rs.getObject(resultIndex[i])));
                }
                out.append("INSERT INTO ").append(t.name).append(" (").append(cols).append(") VALUES (").append(vals).append(");\n");
            }
        }
        if (any) out.append('\n');
    }

    private static int columnIndex(ResultSetMetaData md, String name) throws SQLException {
        for (int i = 1; i <= md.getColumnCount(); i++) {
            if (md.getColumnLabel(i).equalsIgnoreCase(name)) return i;
        }
        return -1;
    }

    /** Un letterale SQL semplice: nessuna sintassi specifica di un motore. */
    static String formatValue(Object v) {
        if (v == null) return "NULL";
        if (v instanceof Boolean b) return b ? "TRUE" : "FALSE";
        if (v instanceof Number n) return n.toString();
        if (v instanceof java.sql.Timestamp ts) return "TIMESTAMP '" + ts.toLocalDateTime() + "'";
        if (v instanceof java.sql.Date d) return "DATE '" + d + "'";
        if (v instanceof java.sql.Time t) return "TIME '" + t + "'";
        return "'" + v.toString().replace("'", "''") + "'";
    }
}
