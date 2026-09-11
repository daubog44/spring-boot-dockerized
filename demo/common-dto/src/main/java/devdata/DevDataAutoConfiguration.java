package devdata;

import jakarta.persistence.EntityManagerFactory;
import jakarta.validation.Validator;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

import javax.sql.DataSource;

/**
 * Accende {@link DevData} in ogni modulo che ha JPA e dipende da common-dto,
 * senza scrivere niente nel modulo. Registrata in
 * META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports.
 */
@AutoConfiguration
@ConditionalOnClass(name = {"jakarta.persistence.EntityManagerFactory", "jakarta.validation.Validator"})
public class DevDataAutoConfiguration {

    @Bean
    DevData devData(ObjectProvider<EntityManagerFactory> emf, ObjectProvider<DataSource> dataSource,
                    ObjectProvider<Validator> validator, Environment env) {
        return new DevData(emf, dataSource, validator, env);
    }
}
