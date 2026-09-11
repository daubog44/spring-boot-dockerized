# Lezione 18: Sicurezza e Autenticazione con Spring Security

Questa lezione ti spiega come padroneggiare **Spring Security** per l'esame: come funziona dietro le quinte, come configurare utenti e ruoli (in memoria o su database), come gestire il login (API REST o interfaccia web Thymeleaf) e come rispondere alle domande teoriche su OAuth2, Keycloak e JWT.

---

## 1. Come Funziona Spring Security: La Catena dei Filtri

Spring Security non è magia: è un insieme di filtri servlet (**Filter Chain**) posizionati davanti ai tuoi controller Spring MVC:

```
Richiesta HTTP (Browser / Postman / Feign)
      │
      ▼
┌────────────────────────────────────────────────────────┐
│               SecurityFilterChain                      │
│                                                        │
│ 1. CsrfFilter: Controlla il token CSRF su POST/PUT/DEL │
│ 2. LogoutFilter: Intercetta /logout                   │
│ 3. UsernamePasswordAuthenticationFilter: /login       │
│ 4. BasicAuthenticationFilter: Header Authorization    │
│ 5. AuthorizationFilter: Verifica ruoli e permessi     │
└────────────────────────────────────────────────────────┘
      │
      ▼ (Se autorizzato)
DispatcherServlet ──> Tuo @RestController o @Controller
```

Quando aggiungi `spring-boot-starter-security` al pom, Spring Boot attiva una configurazione predefinita molto severa:
1. **Blocca tutto con 401 Unauthorized**: qualsiasi endpoint richiede login.
2. **Genera una password alfanumerica a caso** nei log ad ogni riavvio.
3. **Attiva il controllo CSRF**: qualsiasi chiamata REST `POST`/`PUT`/`DELETE` viene bloccata con **403 Forbidden** se non possiede il token CSRF.

---

## 2. Le Due Modalità di Autenticazione all'Esame

La traccia d'esame richiede tipicamente una di queste due modalità:

### A. API REST (Microservizi Backend)
- Si usa l'autenticazione **HTTP Basic**: le credenziali viaggiano nell'header HTTP `Authorization: Basic base64(user:pass)`.
- Si **disabilita il CSRF** (`csrf.disable()`) perché le chiamate tra microservizi o da Swagger non mantengono sessioni cookie del browser.
- Si lasciano aperte in `permitAll()` le rotte tecniche (`/swagger-ui/**`, `/v3/api-docs/**`, `/actuator/**`, `/h2-console/**`).

### B. Web UI (Applicazione Frontend Thymeleaf)
- Si usa il **Form Login**: un form HTML (`/login`) in cui l'utente inserisce username e password.
- In caso di successo, Spring Security crea una **sessione HTTP** e salva l'utente loggato nel `SecurityContext`.
- Si predispone il logout (`/logout`) che invalida la sessione.
- Nei template HTML si mostrano/nascondono pulsanti in base al ruolo dell'utente loggato.

---

## 3. Il Comando Rapido: `task new-auth`

Per evitare di scrivere decine di righe di configurazione, usa `task new-auth`:

```bash
# Modalità 1: In-Memory REST (per un microservizio di backend)
task new-auth SERVICE=ordini-service TYPE=inmemory

# Modalità 2: Database (Entity Utente + Repo + UserDetailsService + BCrypt)
task new-auth SERVICE=ordini-service TYPE=db

# Modalità 3: Form Login Web (per un modulo UI con login.html e sessioni)
task new-auth SERVICE=store-ui TYPE=form
```

---

## 4. Approfondimento Tecnico: Le Tre Architetture

### Architettura 1: Autenticazione In-Memory (Semplice & Veloce)

Ideale quando la traccia dice: *"Proteggi le API con credenziali admin e user"*.

```java
// config/SecurityConfig.java
package esame.ordiniservice.config;

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
            .csrf(csrf -> csrf.disable()) // Obbligatorio per REST/Swagger
            .headers(headers -> headers.frameOptions(f -> f.disable())) // Per console H2
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/**", "/h2-console/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .httpBasic(httpBasic -> {}); // Abilita Basic Auth

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
```

---

### Architettura 2: Autenticazione su Database (Entity + Service)

Quando la traccia richiede che gli utenti siano persistiti su tabella SQL:

1. **Entità JPA (`UtenteEntity.java`)**:
   ```java
   @Entity
   @Table(name = "utenti")
   @Getter @Setter @NoArgsConstructor @AllArgsConstructor
   public class UtenteEntity {
       @Id
       @GeneratedValue(strategy = GenerationType.IDENTITY)
       private Long id;

       @Column(nullable = false, unique = true, length = 50)
       private String username;

       @Column(nullable = false, length = 100)
       private String password; // Conserva SEMPRE l'hash BCrypt, mai in chiaro!

       @Column(nullable = false, length = 50)
       private String ruolo; // es: "ROLE_ADMIN", "ROLE_USER"
   }
   ```

2. **Repository (`UtenteRepository.java`)**:
   ```java
   public interface UtenteRepository extends JpaRepository<UtenteEntity, Long> {
       Optional<UtenteEntity> findByUsername(String username);
   }
   ```

3. **`UserDetailsService` Personalizzato**:
   ```java
   @Service
   @RequiredArgsConstructor
   public class CustomUserDetailsService implements UserDetailsService {

       private final UtenteRepository utenteRepository;

       @Override
       public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
           UtenteEntity u = utenteRepository.findByUsername(username)
               .orElseThrow(() -> new UsernameNotFoundException("Utente non trovato: " + username));

           return new User(
               u.getUsername(),
               u.getPassword(),
               Collections.singletonList(new SimpleGrantedAuthority(u.getRuolo()))
           );
       }
   }
   ```

4. **Inizializzazione Dati**:
   In `SecurityConfig`, un bean `CommandLineRunner` inserisce gli utenti predefiniti con password hashata se la tabella è vuota:
   ```java
   @Bean
   public CommandLineRunner seedUsers(UtenteRepository repo, PasswordEncoder encoder) {
       return args -> {
           if (repo.count() == 0) {
               repo.save(new UtenteEntity(null, "admin", encoder.encode("admin123"), "ROLE_ADMIN"));
               repo.save(new UtenteEntity(null, "user", encoder.encode("user123"), "ROLE_USER"));
           }
       };
   }
   ```

---

### Architettura 3: Form Login Web con Thymeleaf

Per le applicazioni Web con interfaccia utente:

1. **Configurazione Spring Security**:
   ```java
   http
       .authorizeHttpRequests(auth -> auth
           .requestMatchers("/login", "/css/**", "/js/**", "/images/**", "/error").permitAll()
           .requestMatchers("/admin/**").hasRole("ADMIN")
           .anyRequest().authenticated()
       )
       .formLogin(form -> form
           .loginPage("/login")             // La nostra rotta personalizzata
           .defaultSuccessUrl("/", true)    // Dove andare dopo il login
           .permitAll()
       )
       .logout(logout -> logout
           .logoutUrl("/logout")
           .logoutSuccessUrl("/login?logout")
           .permitAll()
       );
   ```

2. **Controller (`LoginController.java`)**:
   ```java
   @Controller
   public class LoginController {
       @GetMapping("/login")
       public String login() {
           return "login"; // punta a templates/login.html
       }
   }
   ```

3. **Pagina HTML (`templates/login.html`)**:
   Deve contenere un form con metodo `post` verso `@{/login}`:
   ```html
   <form th:action="@{/login}" method="post">
       <!-- Se il login fallisce, Spring aggiunge ?error -->
       <div th:if="${param.error}" class="alert-error">
           Credenziali non corrette!
       </div>
       <!-- Dopo il logout, Spring aggiunge ?logout -->
       <div th:if="${param.logout}" class="alert-info">
           Disconnesso con successo.
       </div>

       <label>Username</label>
       <input type="text" name="username" required>

       <label>Password</label>
       <input type="password" name="password" required>

       <button type="submit">Accedi</button>
   </form>
   ```

---

## 5. Taglib di Sicurezza in Thymeleaf

Nel template del modulo UI (con `thymeleaf-extras-springsecurity6`), puoi mostrare elementi HTML condizionatamente al ruolo dell'utente:

Dichiara il namespace in cima all'HTML:
```html
<html xmlns:th="http://www.thymeleaf.org"
      xmlns:sec="http://www.thymeleaf.org/extras/spring-security">
```

### Esempi di utilizzo:

1. **Mostrare il nome dell'utente loggato**:
   ```html
   <span>Benvenuto, <strong sec:authentication="name">Utente</strong>!</span>
   ```

2. **Mostrare un pulsante solo agli amministratori**:
   ```html
   <div sec:authorize="hasRole('ADMIN')">
       <a href="/nuovo-prodotto" class="btn btn-danger">Crea Prodotto</a>
   </div>
   ```

3. **Mostrare un blocco solo se l'utente è anonimo (non loggato)**:
   ```html
   <div sec:authorize="isAnonymous()">
       <a href="/login">Accedi</a>
   </div>
   ```

4. **Pulsante di Logout con form POST (anti-CSRF)**:
   ```html
   <form th:action="@{/logout}" method="post" sec:authorize="isAuthenticated()">
       <button type="submit" class="btn-logout">Esci</button>
   </form>
   ```

---

## 6. Domande Teoriche d'Esame: Sicurezza & Microservizi

La domanda teorica A dell'esame include spesso concetti di sicurezza in architetture distribuite:

### 1. Come si gestisce l'autenticazione tra microservizi?
- **Infrastruttura Monolitica tradizionale**: sessioni server-side salvate in memoria o su database con cookie `JSESSIONID`. Non scala sui microservizi perché richiederebbe sessioni replicate tra tutti i container.
- **Infrastruttura a Microservizi**:
  - Si usa un **API Gateway** (es. Spring Cloud Gateway) come punto unico di ingresso.
  - L'autenticazione avviene al Gateway tramite un Identity Provider (IdP) come **Keycloak** o protocolli standard come **OAuth2 / OIDC (OpenID Connect)**.
  - Il Gateway valida le credenziali ed emette o propaga un token stateless **JWT (JSON Web Token)** contenente i claim dell'utente (username, ruoli, scadenza) firmato crittograficamente.
  - I microservizi interni (chiamati via Feign) ricevono il token JWT nell'header `Authorization: Bearer <token>` e possono validare i permessi in locale senza interrogare il database centrale.

### 2. Perché la password va sempre cifrata con BCrypt?
- BCrypt è una funzione di hashing a senso unico adattiva (*salted and stretched*). Include automaticamente un valore *salt* casuale per impedire attacchi basati su Rainbow Tables e permette di aumentare il fattore di costo computazionale (*work factor*) per resistere agli attacchi brute-force.
