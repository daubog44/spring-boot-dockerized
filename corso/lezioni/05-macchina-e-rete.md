# La macchina e la rete

<!-- parte: A · Prima di cominciare | quando: la sera prima | durata: 30 minuti, quasi tutti di attesa | obiettivo: Il PC ha quello che serve, sai che cosa passa dalla rete dell'aula e hai già scaricato quello che potrebbe non passare. -->

Il giorno dell'esame non si installa niente e non si scopre niente: si
lavora. Tutto quello che può andare storto con la macchina deve andare storto
la sera prima, quando c'è tempo per rimediare.

## Gli attrezzi

| Che cosa | Perché | Come controlli |
| :--- | :--- | :--- |
| un JDK, dal 17 in su | Maven compila con quello; Spring Boot 4 vuole almeno il 17 | `java -version` |
| Docker Desktop | PostgreSQL e lo stack completo per la demo | `docker info` |
| go-task | i comandi `task` | `task --version` |
| un editor | VS Code con *Extension Pack for Java*, Zed con l'estensione *Java*, oppure IntelliJ | apri un file `.java` |

Maven non si installa: c'è il wrapper `mvnw` nel progetto, che si scarica da
solo la versione giusta. Il template nasce su Java 25; se sulla macchina
dell'esame c'è un altro JDK, il wizard allinea il progetto da solo
(`task set-java` a mano).

## La rete dell'esame: filtrata, non assente

All'esame la rete c'è, ma passa da una **whitelist** di domini. Maven Central
è fra quelli ammessi: le dipendenze Maven si scaricano come a casa, quindi
`task add-dep` e i moduli nuovi funzionano anche se ti serve una libreria che
non avevi previsto. Degli altri domini non si sa niente finché non ci provi.
Un comando ci prova per te, in pochi secondi, e non cambia niente:

```bash
task rete
```

```text
LA RETE, DA QUESTA MACCHINA

  Maven Central        risponde       le dipendenze Maven: moduli nuovi, add-dep, il wrapper
  Docker Hub           NON risponde   le immagini di base: eclipse-temurin e postgres
  Ubuntu               NON risponde   curl dentro l'immagine, quando la cache di Docker non ce l'ha
  GitHub               risponde       git clone e le release del template
  VS Code Marketplace  NON risponde   le estensioni di VS Code

Quello che non passa, e cosa vuol dire:
  Docker Hub           le immagini devono essere gia' sul disco (task offline-prep, la sera prima)
  Ubuntu               docker compose build regge solo con la cache (task offline-prep)
  VS Code Marketplace  valgono solo le estensioni gia' installate
```

(Un esempio: nell'aula vera le righe saranno le sue.) Qualunque risposta del
server, anche un «non autorizzato», vuol dire che il dominio passa; *NON
risponde* vuol dire che il filtro lo ferma, o che non c'è rete.

| Dominio | Che cosa ne dipende | Se non passa |
| :--- | :--- | :--- |
| Maven Central | le dipendenze nuove | si compila solo con quello che è già in `~/.m2` |
| Docker Hub | le immagini `eclipse-temurin` e `postgres` | servono quelle scaricate la sera prima |
| Ubuntu | `curl` dentro l'immagine, alla prima build | serve la cache di Docker della sera prima |
| GitHub | `git clone` | il template arriva dalla chiavetta |
| le estensioni degli editor | autocompletamento e debug | valgono quelle già installate |

## La sera prima: scaricare quello che potrebbe non passare

```bash
task offline-prep
```

Ci mette qualche minuto e fa tutto quello che il giorno dopo potrebbe servire
dalla rete:

1. scarica le dipendenze Maven del progetto e lo compila;
2. in una copia usa-e-getta crea con `new-service` un servizio con database e
   un'interfaccia, e li compila: così in `~/.m2` c'è anche quello che serve ai
   moduli che creerai all'esame (JPA, H2, PostgreSQL, Feign, Swagger,
   Thymeleaf);
3. scarica le immagini Docker di base;
4. fa una prima `docker compose build`, che riempie la cache dei livelli,
   compreso quello che installa `curl`.

Con `ALL=1` scarica anche tutto il catalogo di `add-dep` (security, kafka,
mongodb...): più lento, ma non resta niente di imprevisto. Poi controlla:

```bash
task offline
```

Deve finire con *Tutto pronto*. Dice anche se l'editor ha già quello che gli
serve: l'estensione Java di Zed scarica jdtls, Lombok e il debugger al primo
file `.java` che apri, quindi aprine uno **adesso**, con la rete.

## La chiavetta

Il template è la cartella: niente da installare. Portati:

| Che cosa | Perché |
| :--- | :--- |
| la cartella del progetto, `.git` compreso | è il template, e con `.git` torni indietro con `git checkout .` |
| la cartella `~/.m2/repository` | le dipendenze Maven, se Maven Central non dovesse passare |
| gli installatori di go-task, del JDK e di Docker Desktop | solo se non sei sicuro della macchina |

## Appena ti siedi

Quattro comandi, prima di leggere la traccia:

```bash
task rete
```

```bash
task test
```

```bash
task dev
```

```bash
task dev-down
```

`task rete` ti dice che cosa passa oggi. `task test` collauda gli strumenti su
una copia usa-e-getta del progetto (non tocca il tuo): se passa, sai che
`new-service`, `add-dep`, `seed-data` e gli altri funzionano su questa
macchina. `task dev` e `task dev-down` sono un giro a vuoto che scalda Maven e
libera le porte. Se falliscono, hai ancora tutto il tempo per capire perché.

> **Attenzione**
>
> Nei laboratori capita che la porta 5432 sia già di un PostgreSQL installato,
> o la 8080 di un'altra applicazione. Il wizard se ne accorge e propone
> un'altra porta; `task status` ti dice chi occupa che cosa.

> **Fatto quando**
>
> - [ ] `java -version`, `docker info` e `task --version` rispondono
> - [ ] hai letto che cosa dice `task rete` a casa tua
> - [ ] `task offline-prep` è finito e `task offline` dice *Tutto pronto*
> - [ ] hai aperto un file `.java` nell'editor, con la rete
> - [ ] `task test` passa
