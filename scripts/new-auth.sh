#!/usr/bin/env bash
# Configura Spring Security con utenti e autenticazione per un modulo.
# Equivalente POSIX di scripts/new-auth.ps1.
#
#   task new-auth SERVICE=ordini-service [TYPE=inmemory|db|form]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

SERVICE=""
TYPE=""

while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    -Type|--type) TYPE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SERVICE" ]; then
  if [ ! -t 0 ]; then
    echo "Uso: task new-auth SERVICE=<modulo> [TYPE=inmemory|db|form]" >&2
    exit 1
  fi

  ALL_MODULES=()
  for d in "$DEMO_DIR"/*; do
    if [ -f "$d/pom.xml" ] && [ "$(basename "$d")" != "common-dto" ]; then
      ALL_MODULES+=("$(basename "$d")")
    fi
  done
  if [ "${#ALL_MODULES[@]}" -eq 0 ]; then
    echo "Non ci sono moduli in demo/." >&2
    exit 1
  fi

  echo ""
  echo "CONFIGURAZIONE SICUREZZA (SPRING SECURITY) GUIDATA"
  echo "Seleziona il modulo in cui configurare la sicurezza:"
  for i in "${!ALL_MODULES[@]}"; do
    echo "  $((i+1))) ${ALL_MODULES[$i]}"
  done
  printf "  [1] > "
  read -r IDX
  [ -n "$IDX" ] || IDX=1
  SERVICE="${ALL_MODULES[$((IDX-1))]}"

  if [ -z "$TYPE" ]; then
    POM="$DEMO_DIR/$SERVICE/pom.xml"
    DEFAULT_TYPE="inmemory"
    if grep -q '<artifactId>spring-boot-starter-thymeleaf</artifactId>' "$POM"; then
      DEFAULT_TYPE="form"
    fi
    echo "Modalita' di autenticazione: [1] inmemory (Basic Auth per REST), [2] db (tabella utenti + BCrypt), [3] form (login web HTML)"
    printf "  [Default: %s] > " "$DEFAULT_TYPE"
    read -r TANS
    if [ "$TANS" = "1" ]; then TYPE="inmemory"; fi
    if [ "$TANS" = "2" ]; then TYPE="db"; fi
    if [ "$TANS" = "3" ]; then TYPE="form"; fi
  fi
fi

MODULE_DIR="$DEMO_DIR/$SERVICE"
if [ ! -f "$MODULE_DIR/pom.xml" ]; then
  echo "Non trovo il modulo '$SERVICE' in demo/." >&2
  exit 1
fi

POM="$MODULE_DIR/pom.xml"

# Rilevamento automatico del tipo se omesso
if [ -z "$TYPE" ]; then
  if grep -q '<artifactId>spring-boot-starter-thymeleaf</artifactId>' "$POM"; then
    TYPE="form"
  else
    TYPE="inmemory"
  fi
fi
TYPE="$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')"

case "$TYPE" in
  inmemory|db|form) ;;
  *) echo "TYPE non valido: '$TYPE'. Valori ammessi: inmemory, db, form." >&2; exit 1 ;;
esac

echo ""
echo "==> Configurazione Spring Security per $SERVICE (modalita': $TYPE)"
echo ""

# 1. Aggiunta dipendenze
if ! grep -q '<artifactId>spring-boot-starter-security</artifactId>' "$POM"; then
  bash "$SCRIPT_DIR/add-dep.sh" --module "$SERVICE" --deps "security" >/dev/null
  echo "  Aggiunto spring-boot-starter-security a demo/$SERVICE/pom.xml"
fi

if [ "$TYPE" = "form" ]; then
  if ! grep -q 'thymeleaf-extras-springsecurity' "$POM"; then
    bash "$SCRIPT_DIR/add-dep.sh" --module "$SERVICE" --deps "org.thymeleaf.extras:thymeleaf-extras-springsecurity6" >/dev/null
    echo "  Aggiunto thymeleaf-extras-springsecurity6 a demo/$SERVICE/pom.xml"
  fi
elif [ "$TYPE" = "db" ]; then
  if ! grep -q '<artifactId>spring-boot-starter-data-jpa</artifactId>' "$POM"; then
    bash "$SCRIPT_DIR/add-dep.sh" --module "$SERVICE" --deps "data-jpa" >/dev/null
    echo "  Aggiunto spring-boot-starter-data-jpa a demo/$SERVICE/pom.xml"
  fi
fi

BASE_PKG="$(base_package "$DEMO_DIR")"
PKG="$BASE_PKG.$(printf '%s' "$SERVICE" | tr -cd 'a-zA-Z0-9')"
PKG_PATH="$(printf '%s' "$PKG" | tr '.' '/')"
BASE_DIR="$MODULE_DIR/src/main/java/$PKG_PATH"

if [ "$TYPE" = "db" ]; then
  # --- Entity Utente ---
  ENTITY_DIR="$BASE_DIR/entity"
  mkdir -p "$ENTITY_DIR"
  cat > "$ENTITY_DIR/UtenteEntity.java" <<EOF
package $PKG.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "utenti")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class UtenteEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @NotBlank
    @Column(nullable = false, length = 100)
    private String password;

    @NotBlank
    @Column(nullable = false, length = 50)
    private String ruolo; // es: "ROLE_ADMIN", "ROLE_USER"
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/entity/UtenteEntity.java"

  # --- Repository Utente ---
  REPO_DIR="$BASE_DIR/repository"
  mkdir -p "$REPO_DIR"
  cat > "$REPO_DIR/UtenteRepository.java" <<EOF
package $PKG.repository;

import $PKG.entity.UtenteEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UtenteRepository extends JpaRepository<UtenteEntity, Long> {
    Optional<UtenteEntity> findByUsername(String username);
    boolean existsByUsername(String username);
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/repository/UtenteRepository.java"

  # --- UserDetailsService ---
  SERVICE_DIR="$BASE_DIR/service"
  mkdir -p "$SERVICE_DIR"
  cat > "$SERVICE_DIR/CustomUserDetailsService.java" <<EOF
package $PKG.service;

import $PKG.entity.UtenteEntity;
import $PKG.repository.UtenteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.Collections;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UtenteRepository utenteRepository;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        UtenteEntity utente = utenteRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("Utente non trovato: " + username));

        return new User(
                utente.getUsername(),
                utente.getPassword(),
                Collections.singletonList(new SimpleGrantedAuthority(utente.getRuolo()))
        );
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/service/CustomUserDetailsService.java"

  # --- SecurityConfig DB ---
  CONFIG_DIR="$BASE_DIR/config"
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/SecurityConfig.java" <<EOF
package $PKG.config;

import $PKG.entity.UtenteEntity;
import $PKG.repository.UtenteRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .headers(headers -> headers.frameOptions(frame -> frame.disable()))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/**", "/h2-console/**").permitAll()
                // Regole di autorizzazione per ruolo:
                // .requestMatchers("/api/admin/**").hasAuthority("ROLE_ADMIN")
                .anyRequest().permitAll()
            )
            .httpBasic(httpBasic -> {});

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CommandLineRunner seedUsers(UtenteRepository repo, PasswordEncoder encoder) {
        return args -> {
            if (repo.count() == 0) {
                repo.save(new UtenteEntity(null, "admin", encoder.encode("admin123"), "ROLE_ADMIN"));
                repo.save(new UtenteEntity(null, "user", encoder.encode("user123"), "ROLE_USER"));
            }
        };
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/config/SecurityConfig.java"

elif [ "$TYPE" = "form" ]; then
  # --- Controller Login ---
  CTRL_DIR="$BASE_DIR/controller"
  mkdir -p "$CTRL_DIR"
  cat > "$CTRL_DIR/LoginController.java" <<EOF
package $PKG.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class LoginController {

    @GetMapping("/login")
    public String login() {
        return "login";
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/controller/LoginController.java"

  # --- Template login.html ---
  TPL_DIR="$MODULE_DIR/src/main/resources/templates"
  mkdir -p "$TPL_DIR"
  cat > "$TPL_DIR/login.html" <<EOF
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Accedi al Sistema</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; background: #f1f5f9; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
        .card { background: white; border-radius: 8px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); padding: 2rem; width: 100%; max-width: 400px; }
        h1 { margin-top: 0; font-size: 1.5rem; color: #0f172a; text-align: center; }
        .form-group { margin-bottom: 1.25rem; }
        label { display: block; font-weight: 500; margin-bottom: 0.35rem; color: #334155; }
        input[type="text"], input[type="password"] { width: 100%; box-sizing: border-box; padding: 0.6rem 0.75rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 1rem; }
        .btn { width: 100%; background: #2563eb; color: white; border: none; padding: 0.75rem; border-radius: 6px; font-size: 1rem; font-weight: 600; cursor: pointer; }
        .btn:hover { background: #1d4ed8; }
        .alert-error { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 0.75rem; border-radius: 6px; margin-bottom: 1rem; font-size: 0.875rem; text-align: center; }
        .alert-info { background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; padding: 0.75rem; border-radius: 6px; margin-bottom: 1rem; font-size: 0.875rem; text-align: center; }
        .hint { font-size: 0.8rem; color: #64748b; margin-top: 1rem; text-align: center; }
    </style>
</head>
<body>
<div class="card">
    <h1>Autenticazione</h1>

    <div th:if="\${param.error}" class="alert-error">
        Nome utente o password non validi.
    </div>
    <div th:if="\${param.logout}" class="alert-info">
        Disconnessione effettuata con successo.
    </div>

    <form th:action="@{/login}" method="post">
        <div class="form-group">
            <label for="username">Nome Utente</label>
            <input type="text" id="username" name="username" required autofocus placeholder="admin o user">
        </div>
        <div class="form-group">
            <label for="password">Password</label>
            <input type="password" id="password" name="password" required placeholder="admin123 o user123">
        </div>
        <button type="submit" class="btn">Accedi</button>
    </form>

    <div class="hint">
        Credenziali di prova:<br>
        <strong>admin / admin123</strong> (Amministratore)<br>
        <strong>user / user123</strong> (Utente standard)
    </div>
</div>
</body>
</html>
EOF
  echo "  demo/$SERVICE/src/main/resources/templates/login.html"

  # --- SecurityConfig Form Login ---
  CONFIG_DIR="$BASE_DIR/config"
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/SecurityConfig.java" <<EOF
package $PKG.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/login", "/css/**", "/js/**", "/images/**", "/error").permitAll()
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/actuator/**").permitAll()
                // Regole di autorizzazione per ruolo:
                // .requestMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .formLogin(form -> form
                .loginPage("/login")
                .defaultSuccessUrl("/", true)
                .permitAll()
            )
            .logout(logout -> logout
                .logoutUrl("/logout")
                .logoutSuccessUrl("/login?logout")
                .permitAll()
            );

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService(PasswordEncoder encoder) {
        UserDetails admin = User.builder()
            .username("admin")
            .password(encoder.encode("admin123"))
            .roles("ADMIN", "USER")
            .build();

        UserDetails user = User.builder()
            .username("user")
            .password(encoder.encode("user123"))
            .roles("USER")
            .build();

        return new InMemoryUserDetailsManager(admin, user);
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/config/SecurityConfig.java"

else
  # --- In-Memory (Standard REST) ---
  CONFIG_DIR="$BASE_DIR/config"
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/SecurityConfig.java" <<EOF
package $PKG.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .headers(headers -> headers.frameOptions(frame -> frame.disable()))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/**", "/h2-console/**").permitAll()
                // Regole di autorizzazione per ruolo:
                // .requestMatchers(HttpMethod.POST, "/api/**").hasRole("ADMIN")
                .anyRequest().permitAll()
            )
            .httpBasic(httpBasic -> {});

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService(PasswordEncoder encoder) {
        UserDetails admin = User.builder()
            .username("admin")
            .password(encoder.encode("admin123"))
            .roles("ADMIN", "USER")
            .build();

        UserDetails user = User.builder()
            .username("user")
            .password(encoder.encode("user123"))
            .roles("USER")
            .build();

        return new InMemoryUserDetailsManager(admin, user);
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PKG_PATH/config/SecurityConfig.java"
fi

echo ""
echo "Sicurezza configurata con successo per '$SERVICE' (TYPE=$TYPE)."
echo "Per applicare le modifiche ed aggiornare il classpath: task dev"
echo ""
