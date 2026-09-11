# L'algoritmo della traccia

<!-- parte: B · Svolgere la traccia | quando: 11:10 | durata: 30 minuti | obiettivo: La penale è calcolata da due funzioni pure, provata da un test che si lancia in un secondo e descritta nell'allegato come la vuole la commissione. -->

Ogni traccia ha la sua regola da calcolare: la distanza più corta nel
magazzino, la classe energetica di un edificio, la penale per chi restituisce
tardi. Vale punti due volte: nel codice e nell'allegato. Conviene scriverla in
modo che si possa provare da sola.

## Dalla frase alla formula

La traccia dice: *per ogni giorno di ritardo si paga una penale di 0,50 euro,
fino a un massimo di 20 euro*. Prima di scrivere codice, la si scrive così:

- **ritardo** = giorni fra la scadenza e il giorno di riferimento, e mai meno
  di zero;
- **giorno di riferimento** = il giorno della restituzione se il prestito è
  chiuso, oggi se è ancora aperto;
- **penale** = il minore fra 0,50 × ritardo e 20,00.

Restituito in anticipo: ritardo 0, penale 0. Quaranta giorni di ritardo: la
formula darebbe 20,00 esatti, oltre si resta a 20,00.

## Il codice

```java demo/prestiti-service/src/main/java/esame/prestitiservice/service/PrestitoService.java
static final BigDecimal PENALE_GIORNALIERA = new BigDecimal("0.50");
static final BigDecimal PENALE_MASSIMA = new BigDecimal("20.00");

// 0,50 euro per ogni giorno oltre la scadenza, fino a un massimo di 20
// euro. Per un prestito ancora aperto il ritardo si conta fino a oggi, per
// uno chiuso fino al giorno della restituzione. Due funzioni pure, senza
// database ne' Feign: si provano con un test in un attimo.

static long giorniRitardo(LocalDate scadenza, LocalDate riferimento) {
    return Math.max(0, ChronoUnit.DAYS.between(scadenza, riferimento));
}

static BigDecimal penale(long giorniRitardo) {
    return PENALE_GIORNALIERA.multiply(BigDecimal.valueOf(giorniRitardo)).min(PENALE_MASSIMA);
}

private PrestitoDto toDto(PrestitoEntity p, String titolo, LocalDate oggi) {
    LocalDate riferimento = p.getDataRestituzione() != null ? p.getDataRestituzione() : oggi;
    long ritardo = giorniRitardo(p.getDataScadenza(), riferimento);
    return new PrestitoDto(p.getId(), p.getLibroId(), titolo, p.getUtenteEmail(), p.getDataPrestito(),
            p.getDataScadenza(), p.getStato().name(), ritardo, penale(ritardo));
}
```

- **Due funzioni pure**: ricevono tutto quello che serve come parametro e non
  toccano né database né rete. Si provano in un millisecondo, e si leggono in
  un colpo d'occhio all'orale.
- **`BigDecimal` per i soldi**, sempre: con `double`, 0,1 + 0,2 fa
  0,30000000000000004. I valori si creano da stringa (`new BigDecimal("0.50")`)
  per lo stesso motivo.
- **`static` e senza `private`**: le vede il test, che sta nello stesso
  pacchetto, e nessun altro fuori.
- `ChronoUnit.DAYS.between` conta i giorni di calendario fra due `LocalDate`,
  senza fusi orari e ore legali di mezzo.

## Il test

```java demo/prestiti-service/src/test/java/esame/prestitiservice/service/PenaleTest.java
class PenaleTest {

    private static final LocalDate SCADENZA = LocalDate.of(2026, 3, 10);

    @Test
    void restituitoInTempoNonHaRitardo() {
        assertEquals(0, PrestitoService.giorniRitardo(SCADENZA, SCADENZA));
        assertEquals(0, PrestitoService.giorniRitardo(SCADENZA, SCADENZA.minusDays(4)));
    }

    @Test
    void ogniGiornoDopoLaScadenzaConta() {
        assertEquals(7, PrestitoService.giorniRitardo(SCADENZA, SCADENZA.plusDays(7)));
    }

    @Test
    void cinquantaCentesimiAlGiorno() {
        assertEquals(new BigDecimal("3.50"), PrestitoService.penale(7));
    }

    @Test
    void laPenaleSiFermaAVentiEuro() {
        assertEquals(new BigDecimal("20.00"), PrestitoService.penale(40));
        assertEquals(new BigDecimal("20.00"), PrestitoService.penale(400));
    }
}
```

Serve JUnit, che i moduli generati non hanno: si aggiunge con un comando.

```bash
task add-dep SERVICE=prestiti-service DEPS=test
```

Poi, dalla cartella `demo` (su Windows `.\mvnw.cmd` al posto di `./mvnw`):

```bash
./mvnw -pl prestiti-service -am test
```

```text
[INFO] Tests run: 4, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

`task dev`, `task build` e le immagini Docker saltano i test
(`-Dmaven.test.skip=true`), così un test rotto non ti blocca lo stack a metà
giornata: si lanciano quando li chiedi tu.

## Nell'allegato

La commissione vuole l'algoritmo spiegato, non incollato. Un paragrafo così
basta:

> **Algoritmo della penale.** Per ogni prestito si calcola il ritardo come il
> numero di giorni fra la data di scadenza e la data di riferimento — la data
> di restituzione se il prestito è chiuso, la data odierna se è aperto — con
> un minimo di zero. La penale è pari a 0,50 € per giorno di ritardo, con un
> tetto di 20,00 €: penale = min(0,50 × ritardo; 20,00). Il calcolo avviene in
> `PrestitoService` (metodi `giorniRitardo` e `penale`) ogni volta che un
> prestito viene restituito all'esterno, quindi il valore mostrato è sempre
> aggiornato al giorno corrente e non viene salvato nel database. Costa un
> tempo costante per prestito, lineare nel numero di prestiti per l'elenco.
> È verificato dai test di `PenaleTest`: restituzione in anticipo, sette
> giorni di ritardo (3,50 €), tetto raggiunto (20,00 €).

## Gli algoritmi delle altre tracce

Stesso schema, sempre: formula a parole, funzione pura, test, paragrafo. Nel
magazzino WMS (branch `solution/wms`) la regola è trovare l'ubicazione libera
più vicina, con la distanza di Manhattan fra armadi disposti a griglia:
|riga₁ − riga₂| + |colonna₁ − colonna₂|, calcolata su tutte le ubicazioni
compatibili e presa la minima.

> **Prova tu**
>
> La biblioteca cambia idea: la prima settimana di ritardo costa 0,20 € al
> giorno, dall'ottavo giorno 0,50 €, sempre con il tetto di 20 €. Scrivi prima
> i test (sette giorni: 1,40 €; dieci giorni: 2,90 €), poi cambia `penale`
> finché passano.

> **Fatto quando**
>
> - [ ] la formula è scritta a parole prima che in Java
> - [ ] il calcolo sta in funzioni che non toccano database e rete
> - [ ] `./mvnw -pl prestiti-service -am test` passa
> - [ ] il paragrafo per l'allegato è scritto
