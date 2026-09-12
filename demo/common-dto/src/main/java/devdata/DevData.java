package devdata;

import jakarta.persistence.EntityManagerFactory;
import jakarta.validation.Validator;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.context.ApplicationListener;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.core.env.Environment;

import javax.sql.DataSource;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

/**
 * Dati di prova e schema, a partire dal database vero.
 *
 * Parte quando l'applicazione ha finito di avviarsi, cioe' dopo che Hibernate
 * ha creato le tabelle. Legge tre proprieta' (in application.yml o sulla riga
 * di comando):
 *
 * <pre>
 *   dev-data.rows=5              riempie con 5 righe le tabelle ancora vuote
 *   dev-data.schema-out=file.md  scrive lo schema del database in markdown
 *   dev-data.sql-out=data.sql    scrive le righe generate come INSERT SQL
 *   dev-data.exit=true           finito il lavoro, chiude l'applicazione
 * </pre>
 *
 * Senza nessuna delle tre non fa niente. Le usano task seed-data e task
 * db-schema; i messaggi cominciano tutti con [dev-data].
 */
public class DevData implements ApplicationListener<ContextRefreshedEvent>, ApplicationContextAware {

    private final ObjectProvider<EntityManagerFactory> emf;
    private final ObjectProvider<DataSource> dataSource;
    private final ObjectProvider<Validator> validator;
    private final Environment env;
    private ApplicationContext context;
    private boolean done;

    public DevData(ObjectProvider<EntityManagerFactory> emf, ObjectProvider<DataSource> dataSource,
                   ObjectProvider<Validator> validator, Environment env) {
        this.emf = emf;
        this.dataSource = dataSource;
        this.validator = validator;
        this.env = env;
    }

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) {
        this.context = applicationContext;
    }

    @Override
    public void onApplicationEvent(ContextRefreshedEvent event) {
        // Feign e Spring Cloud accendono contesti figli che rimandano l'evento
        // qui: conta solo quello dell'applicazione, una volta.
        if (event.getApplicationContext() != context || done) return;
        done = true;

        int rows = env.getProperty("dev-data.rows", Integer.class, 0);
        String schemaOut = env.getProperty("dev-data.schema-out", "");
        String sqlOut = env.getProperty("dev-data.sql-out", "");
        boolean exit = env.getProperty("dev-data.exit", Boolean.class, false);
        if (rows <= 0 && schemaOut.isBlank() && sqlOut.isBlank() && !exit) return;

        int status = 0;
        EntityManagerFactory factory = emf.getIfAvailable();
        try {
            if (factory == null) {
                say("nessun database JPA in questo modulo: niente da fare");
            } else {
                if (rows > 0) {
                    Seeder seeder = new Seeder(factory, validator.getIfUnique(), rows);
                    List<String> report = seeder.run();
                    report.forEach(DevData::say);
                    if (seeder.failedEntities() > 0) status = 3;
                    DataSource ds = dataSource.getIfAvailable();
                    if (ds != null) say("righe per tabella: " + SchemaWriter.counts(ds));
                }
                if (!schemaOut.isBlank()) {
                    String markdown = new SchemaWriter(factory, dataSource.getObject()).write();
                    Path path = Path.of(schemaOut).toAbsolutePath();
                    if (path.getParent() != null) Files.createDirectories(path.getParent());
                    Files.writeString(path, markdown, StandardCharsets.UTF_8);
                    say("schema scritto in " + path);
                }
                if (!sqlOut.isBlank()) {
                    String sql = new DataSqlWriter(factory, dataSource.getObject()).write();
                    Path path = Path.of(sqlOut).toAbsolutePath();
                    if (path.getParent() != null) Files.createDirectories(path.getParent());
                    Files.writeString(path, sql, StandardCharsets.UTF_8);
                    say("data.sql scritto in " + path);
                }
            }
        } catch (Exception | LinkageError e) {
            say("ERRORE " + Seeder.rootMessage(e));
            status = 4;
        }
        if (exit) {
            System.out.flush();
            // halt e non exit: siamo ancora dentro l'avvio di Spring, e chiudere
            // il contesto da qui puo' bloccarsi. Il database e' usa-e-getta.
            Runtime.getRuntime().halt(status);
        }
    }

    private static void say(String line) {
        System.out.println("[dev-data] " + line);
    }
}
