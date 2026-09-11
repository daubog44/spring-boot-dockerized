# Allegato tecnico: le parti scritte da te

task consegna prende ogni sezione di questo file e la mette al suo posto in
ALLEGATO-TECNICO.md, accanto a quello che ricava dal progetto (moduli, porte,
endpoint, schema del database). Scrivi sotto ogni titolo e lascia i titoli
come sono: una sezione ancora fra parentesi quadre conta come da scrivere, e
la consegna te lo ricorda.

## Analisi

La biblioteca di quartiere informatizza il catalogo e i prestiti. Il
bibliotecario consulta i libri, con autore, genere, anno e disponibilità;
registra un prestito indicando l'email di chi prende il libro e la durata (30
giorni di norma, al massimo 60); registra la restituzione. Il sistema impedisce
di prestare un libro già fuori e calcola, per ogni prestito, i giorni di
ritardo e la penale.

La soluzione è divisa in tre microservizi, ognuno con i suoi dati: il catalogo
possiede libri e autori, i prestiti possiedono i prestiti e dei libri tengono
solo l'identificativo. La coerenza fra i due la mantiene il servizio dei
prestiti: prima di prestare chiede il libro al catalogo, dopo gli comunica che
non è più disponibile, e alla restituzione che lo è di nuovo. L'interfaccia web
chiama entrambi. Tutti si registrano su Eureka e si chiamano per nome con
OpenFeign.

## Algoritmo

Per ogni prestito si calcola il ritardo come il numero di giorni fra la data di
scadenza e la data di riferimento — la data di restituzione se il prestito è
chiuso, la data odierna se è aperto — con un minimo di zero. La penale è pari a
0,50 € per giorno di ritardo, con un tetto di 20,00 €:

penale = min(0,50 × ritardo; 20,00)

Il calcolo sta in `PrestitoService` (metodi `giorniRitardo` e `penale`), due
funzioni pure che non toccano né il database né la rete, e si esegue ogni volta
che un prestito viene restituito all'esterno: il valore mostrato è sempre
aggiornato al giorno corrente e non viene salvato. Il costo è costante per
prestito e lineare nel numero di prestiti per l'elenco. Gli importi usano
`BigDecimal`, per non avere errori di arrotondamento. I test di `PenaleTest`
verificano la restituzione in anticipo (nessuna penale), sette giorni di
ritardo (3,50 €) e il tetto (20,00 € da quaranta giorni in su).

## naming-server

Il registro Eureka: i servizi vi si registrano col loro nome
(`spring.application.name`) e lo usano per trovarsi, senza indirizzi scritti
nel codice.

## catalogo-service

Tiene libri e autori su PostgreSQL (database `biblioteca`) e li espone in REST.
Il servizio dei prestiti lo chiama per leggere un libro e per cambiarne la
disponibilità.

## prestiti-service

Registra prestiti e restituzioni su un database suo (`prestiti`). Chiede i
libri al catalogo via Feign: risponde 404 se il libro non esiste, 409 se è già
in prestito, 400 se i dati della richiesta non sono validi. Calcola ritardo e
penale di ogni prestito.

## biblioteca-ui

L'interfaccia web, con Thymeleaf: mostra catalogo e prestiti con ritardo e
penale, registra un prestito con un form validato e una restituzione con un
bottone. Se un servizio non risponde la pagina lo dice, invece di andare in
errore.

## Domanda A

[Facoltativa: la risposta alla domanda teorica, se la traccia la vuole nell'allegato.]

## Domanda B

[Facoltativa: la risposta alla domanda teorica, se la traccia la vuole nell'allegato.]
