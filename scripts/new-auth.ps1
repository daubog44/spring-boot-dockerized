<#
.SYNOPSIS
    Configura Spring Security con utenti e autenticazione per un modulo.

.DESCRIPTION
    Genera l'impalcatura di sicurezza adatta alla traccia d'esame in tre modalita':

      TYPE=inmemory (default per API REST)
        - Configura Spring Security con HTTP Basic
        - Swagger, Actuator e H2 aperti
        - Utenti pronti: admin/admin123 (ADMIN) e user/user123 (USER)
        - PasswordEncoder BCrypt

      TYPE=db (autenticazione su database)
        - UtenteEntity (@Table "utenti", username unique, password BCrypt, ruolo)
        - UtenteRepository (findByUsername, existsByUsername)
        - CustomUserDetailsService (implements UserDetailsService)
        - SecurityConfig con BCrypt e CommandLineRunner per seed automatico admin/user

      TYPE=form (per moduli Web/UI Thymeleaf)
        - Dipendenza thymeleaf-extras-springsecurity6
        - SecurityConfig con Form Login (/login) e Logout (/logout)
        - LoginController (@GetMapping("/login"))
        - templates/login.html moderno e responsivo con messaggi di errore e logout

.PARAMETER Service
    Nome del modulo (es. catalogo-service, biblioteca-ui).

.PARAMETER Type
    Modalita': inmemory, db, oppure form. Se omesso, deduce automaticamente
    'form' se il modulo ha Thymeleaf, altrimenti 'inmemory'.

.EXAMPLE
    task new-auth SERVICE=ordini-service
    task new-auth SERVICE=ordini-service TYPE=db
    task new-auth SERVICE=store-ui TYPE=form
#>
param(
    [string]$Service = '',
    [string]$Type = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

if (-not $Service) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task new-auth SERVICE=<modulo> [TYPE=inmemory|db|form]"
    }

    $allModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'pom.xml')) -and ($_.Name -ne 'common-dto')
    } | Select-Object -ExpandProperty Name)

    if ($allModules.Count -eq 0) {
        throw "Non ci sono moduli in demo/."
    }

    Write-Host ''
    Write-Host 'CONFIGURAZIONE SICUREZZA (SPRING SECURITY) GUIDATA' -ForegroundColor Cyan
    Write-Host "Seleziona il modulo in cui configurare la sicurezza:" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $allModules.Count; $i++) {
        Write-Host "  $($i + 1)) $($allModules[$i])"
    }
    $idx = Read-Host "  [1] >"
    $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
    $Service = $allModules[$idxNum - 1]

    if (-not $Type) {
        $modPom = Read-TextFile (Join-Path (Join-Path $demoDir $Service) 'pom.xml')
        $isUi = $modPom -match 'spring-boot-starter-thymeleaf'
        $defaultType = if ($isUi) { 'form' } else { 'inmemory' }
        Write-Host "Modalita' di autenticazione: [1] inmemory (Basic Auth per REST), [2] db (tabella utenti + BCrypt), [3] form (login web HTML)" -ForegroundColor DarkGray
        $tAns = (Read-Host "  [Default: $defaultType] >").Trim()
        if ($tAns -eq '1') { $Type = 'inmemory' }
        elseif ($tAns -eq '2') { $Type = 'db' }
        elseif ($tAns -eq '3') { $Type = 'form' }
    }
}

$moduleDir = Join-Path $demoDir $Service
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    throw "Non trovo il modulo '$Service' in demo/."
}

$pomText = Read-TextFile (Join-Path $moduleDir 'pom.xml')

# Rilevamento automatico del tipo se omesso
if (-not $Type) {
    if ($pomText -match '<artifactId>spring-boot-starter-thymeleaf</artifactId>') {
        $Type = 'form'
    } else {
        $Type = 'inmemory'
    }
}
$Type = $Type.ToLower().Trim()
if ($Type -notin @('inmemory', 'db', 'form')) {
    throw "TYPE non valido: '$Type'. Valori ammessi: inmemory, db, form."
}

Write-Host ''
Write-Host "==> Configurazione Spring Security per $Service (modalita': $Type)" -ForegroundColor Cyan
Write-Host ''

# 1. Aggiunta dipendenze
$addDepScript = Join-Path $PSScriptRoot 'add-dep.ps1'
if ($pomText -notmatch '<artifactId>spring-boot-starter-security</artifactId>') {
    & $addDepScript -Module $Service -Deps 'security' | Out-Null
    Write-Step "Aggiunto spring-boot-starter-security a demo/$Service/pom.xml"
}

if ($Type -eq 'form') {
    if ($pomText -notmatch 'thymeleaf-extras-springsecurity') {
        & $addDepScript -Module $Service -Deps 'org.thymeleaf.extras:thymeleaf-extras-springsecurity6' | Out-Null
        Write-Step "Aggiunto thymeleaf-extras-springsecurity6 a demo/$Service/pom.xml"
    }
} elseif ($Type -eq 'db') {
    if ($pomText -notmatch '<artifactId>spring-boot-starter-data-jpa</artifactId>') {
        & $addDepScript -Module $Service -Deps 'data-jpa' | Out-Null
        Write-Step "Aggiunto spring-boot-starter-data-jpa a demo/$Service/pom.xml"
    }
}

$package = Get-ModulePackage -Module $Service
$packagePath = $package -replace '\.', '/'
$baseDir = Join-Path $moduleDir "src/main/java/$packagePath"

# 2. Generazione codice in base a TYPE
if ($Type -eq 'db') {
    # --- Entity Utente ---
    $entityDir = Join-Path $baseDir 'entity'
    if (-not (Test-Path $entityDir)) { New-Item -ItemType Directory -Path $entityDir -Force | Out-Null }
    $entityFile = Join-Path $entityDir 'UtenteEntity.java'
    $entityCode = @"
package $package.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Entita' per la gestione degli utenti e delle credenziali nel database.
 * Generata da task new-auth TYPE=db.
 *
 * Punti di estensione:
 *   - Aggiungi campi profilo come email, nome, cognome o data di registrazione.
 *   - Se l'applicazione richiede ruoli multipli, trasforma 'ruolo' in un Set<String> con @ElementCollection,
 *     oppure crea un'entita' RuoloEntity con relazione @ManyToMany.
 */
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
"@
    Write-TextFile -Path $entityFile -Text $entityCode
    Write-Step "demo/$Service/src/main/java/$packagePath/entity/UtenteEntity.java"

    # --- Repository Utente ---
    $repoDir = Join-Path $baseDir 'repository'
    if (-not (Test-Path $repoDir)) { New-Item -ItemType Directory -Path $repoDir -Force | Out-Null }
    $repoFile = Join-Path $repoDir 'UtenteRepository.java'
    $repoCode = @"
package $package.repository;

import $package.entity.UtenteEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UtenteRepository extends JpaRepository<UtenteEntity, Long> {
    Optional<UtenteEntity> findByUsername(String username);
    boolean existsByUsername(String username);
}
"@
    Write-TextFile -Path $repoFile -Text $repoCode
    Write-Step "demo/$Service/src/main/java/$packagePath/repository/UtenteRepository.java"

    # --- UserDetailsService ---
    $serviceDir = Join-Path $baseDir 'service'
    if (-not (Test-Path $serviceDir)) { New-Item -ItemType Directory -Path $serviceDir -Force | Out-Null }
    $udsFile = Join-Path $serviceDir 'CustomUserDetailsService.java'
    $udsCode = @"
package $package.service;

import $package.entity.UtenteEntity;
import $package.repository.UtenteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.Collections;

/**
 * Caricamento credenziali utente da database per Spring Security.
 * Generato da task new-auth TYPE=db.
 *
 * Punti di estensione:
 *   - Se gestisci ruoli multipli: mappare ogni ruolo come SimpleGrantedAuthority.
 *   - Verificare flag di stato se presenti nell'entita' (es. utente.isAttivo()).
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UtenteRepository utenteRepository;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        UtenteEntity utente = utenteRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("Utente non trovato: " + username));

        // TODO: Se l'utente supporta piu' ruoli, converti la collezione in SimpleGrantedAuthority.
        // Esempio:
        // List<SimpleGrantedAuthority> authorities = utente.getRuoli().stream()
        //         .map(SimpleGrantedAuthority::new)
        //         .toList();

        return new User(
                utente.getUsername(),
                utente.getPassword(),
                Collections.singletonList(new SimpleGrantedAuthority(utente.getRuolo()))
        );
    }
}
"@
    Write-TextFile -Path $udsFile -Text $udsCode
    Write-Step "demo/$Service/src/main/java/$packagePath/service/CustomUserDetailsService.java"

    # --- SecurityConfig DB ---
    $configDir = Join-Path $baseDir 'config'
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $secFile = Join-Path $configDir 'SecurityConfig.java'
    $secCode = @"
package $package.config;

import $package.entity.UtenteEntity;
import $package.repository.UtenteRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Configurazione di sicurezza per $Service (autenticazione su database).
 * Generata da task new-auth TYPE=db.
 *
 * Punti di estensione:
 *   - Modifica le autorizzazioni delle rotte in securityFilterChain().
 *   - hasRole("ADMIN") verifica l'authority "ROLE_ADMIN".
 *   - hasAuthority("ROLE_ADMIN") confronta la stringa esatta dell'authority.
 */
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
                // TODO: Regole di autorizzazione specifiche per le tue rotte (esempi):
                // .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/**").permitAll()
                // .requestMatchers(org.springframework.http.HttpMethod.POST, "/api/**").hasAuthority("ROLE_ADMIN")
                // .requestMatchers("/api/admin/**").hasAuthority("ROLE_ADMIN")
                // TODO: Per proteggere tutti gli altri endpoint richiedendo autenticazione:
                // sostituire la riga seguente con: .anyRequest().authenticated()
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
                // TODO: Aggiungi qui gli utenti iniziali necessari per le prove della traccia d'esame.
                repo.save(new UtenteEntity(null, "admin", encoder.encode("admin123"), "ROLE_ADMIN"));
                repo.save(new UtenteEntity(null, "user", encoder.encode("user123"), "ROLE_USER"));
            }
        };
    }
}
"@
    Write-TextFile -Path $secFile -Text $secCode
    Write-Step "demo/$Service/src/main/java/$packagePath/config/SecurityConfig.java"

} elseif ($Type -eq 'form') {
    # --- Controller Login ---
    $ctrlDir = Join-Path $baseDir 'controller'
    if (-not (Test-Path $ctrlDir)) { New-Item -ItemType Directory -Path $ctrlDir -Force | Out-Null }
    $loginCtrlFile = Join-Path $ctrlDir 'LoginController.java'
    $loginCtrlCode = @"
package $package.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Controller per la gestione della pagina di accesso (login).
 * Generato da task new-auth TYPE=form.
 *
 * Punti di estensione:
 *   - Aggiungi rotte per la registrazione utente (@GetMapping("/register"), @PostMapping("/register")).
 */
@Controller
public class LoginController {

    @GetMapping("/login")
    public String login() {
        return "login";
    }
}
"@
    Write-TextFile -Path $loginCtrlFile -Text $loginCtrlCode
    Write-Step "demo/$Service/src/main/java/$packagePath/controller/LoginController.java"

    # --- Template login.html ---
    $tplDir = Join-Path $moduleDir 'src/main/resources/templates'
    if (-not (Test-Path $tplDir)) { New-Item -ItemType Directory -Path $tplDir -Force | Out-Null }
    $loginHtmlFile = Join-Path $tplDir 'login.html'
    $loginHtmlCode = @"
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

    <div th:if="`$`{param.error}" class="alert-error">
        Nome utente o password non validi.
    </div>
    <div th:if="`$`{param.logout}" class="alert-info">
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
"@
    Write-TextFile -Path $loginHtmlFile -Text $loginHtmlCode
    Write-Step "demo/$Service/src/main/resources/templates/login.html"

    # --- SecurityConfig Form Login ---
    $configDir = Join-Path $baseDir 'config'
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $secFile = Join-Path $configDir 'SecurityConfig.java'
    $secCode = @"
package $package.config;

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

/**
 * Configurazione di sicurezza per l'interfaccia web $Service (form login).
 * Generata da task new-auth TYPE=form.
 *
 * Punti di estensione:
 *   - Proteggi specifiche aree della UI in base al ruolo (es. /admin/**).
 *   - Personalizza defaultSuccessUrl o le pagine di errore.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/login", "/css/**", "/js/**", "/images/**", "/error").permitAll()
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/actuator/**").permitAll()
                // TODO: Regole di autorizzazione per la UI (esempi):
                // .requestMatchers("/admin/**").hasRole("ADMIN")
                // .requestMatchers("/prenotazioni/**").hasAnyRole("USER", "ADMIN")
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
"@
    Write-TextFile -Path $secFile -Text $secCode
    Write-Step "demo/$Service/src/main/java/$packagePath/config/SecurityConfig.java"

} else {
    # --- In-Memory (Standard REST) ---
    $configDir = Join-Path $baseDir 'config'
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $secFile = Join-Path $configDir 'SecurityConfig.java'
    $secCode = @"
package $package.config;

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

/**
 * Configurazione di sicurezza per $Service (autenticazione in-memory).
 * Generata da task new-auth TYPE=inmemory.
 *
 * Punti di estensione:
 *   - Modifica le autorizzazioni delle rotte in securityFilterChain().
 *   - Configura ruoli o utenti aggiuntivi in userDetailsService().
 */
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
                // TODO: Regole di autorizzazione per ruolo (esempi):
                // .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/**").permitAll()
                // .requestMatchers(org.springframework.http.HttpMethod.POST, "/api/**").hasRole("ADMIN")
                // .requestMatchers("/api/admin/**").hasRole("ADMIN")
                // TODO: Per proteggere tutti gli altri endpoint richiedendo autenticazione:
                // sostituire la riga seguente con: .anyRequest().authenticated()
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
"@
    Write-TextFile -Path $secFile -Text $secCode
    Write-Step "demo/$Service/src/main/java/$packagePath/config/SecurityConfig.java"
}

Write-Host ''
Write-Host "Sicurezza configurata con successo per '$Service' (TYPE=$Type)." -ForegroundColor Green
Write-Host "Per applicare le modifiche ed aggiornare il classpath: task dev"
Write-Host ''
