# Spring Boot Dockerized - Template d'Esame ITS

Questo repository è un **Template Multi-Modulo Maven d'Esame** pronto all'uso. È progettato per consentirti di sviluppare rapidamente qualsiasi traccia d'esame (WMS, Catasto, Prenotazione Ospedaliera, Eventi/Turismo, ecc.) basata su **Spring Boot**, **Spring Cloud Eureka**, **OpenFeign**, **OpenAPI/Swagger UI**, **PostgreSQL** e **Docker Compose**.

---

## 📚 Documentazione & Guide per l'Esame

- [📖 Guida 1: Setup & Cheat Sheet Emergenze](./guida_setup_e_cheatsheet.md)
- [📘 Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md)
- [🛠️ Guida 3: Multi-Modulo Maven e Funzionamento](./guida_multi_modulo_maven.md)
- [📝 Documentazione Specifica Esame (README-ESAME-TTFCLOUD.md)](./README-ESAME-TTFCLOUD.md)

---

## 🏗️ Architettura del Template Multi-Modulo

Il progetto è organizzato come un aggregatore Multi-Module Maven dentro la cartella `demo`:

1. **`naming-server`**: Server Eureka Naming Server (Porta `8761`).
2. **`common-dto`**: Modulo libreria con le classi DTO condivise tra i microservizi.
3. **Microservizi Modello / Scheletro**:
   - `tourist-service` (Porta `8081`) - Esempio di wrapper / servizio REST esterno.
   - `random-service` (Porta `8082`) - Esempio di microservizio ausiliario / generatore.
   - `store-service` (Porta `8083`) - Esempio di microservizio REST con persistenza DB PostgreSQL/H2.
4. **`event-ui`**: Applicazione Web UI Thymeleaf / Frontend (Porta `8080`).

> 💡 **Nota per il Giorno dell'Esame**: Puoi rinominare, adattare o aggiungere nuovi moduli all'interno di `demo` in base al contesto della traccia assegnata (es. trasformare `store-service` nel servizio anagrafica WMS o Catasto).

---

## ⚡ Task Principali (`go-task`)

- `task build`: Compila tutti i moduli Maven tramite wrapper (`mvnw`).
- `task docker-up`: Avvia l'intero cluster di microservizi su Docker Compose con healthcheck.
- `task docker-down`: Arresta tutti i container e pulisce le risorse.
- `task docker-logs`: Monitora i log di tutti i microservizi.
- `task clean-ports`: Termina eventuali processi Java rimasti pendenti.

---

## 🌐 Mappa delle Porte ed Interfacce OpenAPI / Swagger UI

- **UI Applicativa**: `http://localhost:8080`
- **Dashboard Eureka**: `http://localhost:8761`
- **Swagger UI Tourist Service**: `http://localhost:8081/swagger-ui.html`
- **Swagger UI Random Service**: `http://localhost:8082/swagger-ui.html`
- **Swagger UI Store Service**: `http://localhost:8083/swagger-ui.html`
- **Swagger UI Event UI**: `http://localhost:8080/swagger-ui.html`
