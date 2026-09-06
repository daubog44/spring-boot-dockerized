package com.example.ttfcloud_esame.wmsservice;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.ttfcloud_esame.common.dto.CabinetDTO;
import com.example.ttfcloud_esame.common.dto.CustomerDTO;
import com.example.ttfcloud_esame.common.dto.LocationDTO;
import com.example.ttfcloud_esame.common.dto.NearestLocationRequest;
import com.example.ttfcloud_esame.common.dto.NearestLocationResponse;
import com.example.ttfcloud_esame.common.dto.ProductDTO;
import com.example.ttfcloud_esame.common.dto.StockMovementRequest;
import com.example.ttfcloud_esame.common.dto.StockMovementResult;
import com.example.ttfcloud_esame.wmsservice.client.CrmClient;
import com.example.ttfcloud_esame.wmsservice.client.ProductClient;
import com.example.ttfcloud_esame.wmsservice.persistence.CabinetEntity;
import com.example.ttfcloud_esame.wmsservice.persistence.CabinetRepository;
import com.example.ttfcloud_esame.wmsservice.persistence.LocationEntity;
import com.example.ttfcloud_esame.wmsservice.persistence.LocationRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class WmsService implements CommandLineRunner {

    private final CabinetRepository cabinetRepository;
    private final LocationRepository locationRepository;
    private final ProductClient productClient;
    private final CrmClient crmClient;

    @Override
    @Transactional
    public void run(String... args) {
        if (cabinetRepository.count() == 0) {
            log.info("Inizializzazione dati di prova per il Magazzino WMS...");
            CabinetEntity c1 = cabinetRepository.save(new CabinetEntity(1L, 1, 1, "Armadio Fila 1 Col 1"));
            CabinetEntity c2 = cabinetRepository.save(new CabinetEntity(2L, 1, 3, "Armadio Fila 1 Col 3"));
            CabinetEntity c3 = cabinetRepository.save(new CabinetEntity(3L, 4, 2, "Armadio Fila 4 Col 2"));

            // Location 1: 4 scatole (Product 101, Customer 201), ingombro unitario 10 -> current 40, max 100
            locationRepository.save(new LocationEntity(1L, c1.getId(), 100, 40, 101L, 201L, 4));
            // Location 2: vuota, max 120
            locationRepository.save(new LocationEntity(2L, c1.getId(), 120, 0, null, null, 0));

            // Location 3: 2 pallet (Product 102, Customer 202), ingombro unitario 50 -> current 100, max 150
            locationRepository.save(new LocationEntity(3L, c2.getId(), 150, 100, 102L, 202L, 2));
            // Location 4: vuota, max 200
            locationRepository.save(new LocationEntity(4L, c2.getId(), 200, 0, null, null, 0));

            // Location 5: 1 contenitore (Product 103, Customer 201), ingombro unitario 25 -> current 25, max 80
            locationRepository.save(new LocationEntity(5L, c3.getId(), 80, 25, 103L, 201L, 1));
            // Location 6: vuota, max 100
            locationRepository.save(new LocationEntity(6L, c3.getId(), 100, 0, null, null, 0));

            log.info("Inizializzati 3 Armadi e 6 Ubicazioni di magazzino.");
        }
    }

    @Transactional(readOnly = true)
    public List<CabinetDTO> getAllCabinets() {
        return cabinetRepository.findAll().stream()
            .map(this::toCabinetDTO)
            .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<LocationDTO> getLocationsByCabinet(Long cabinetId) {
        List<LocationEntity> locations = (cabinetId == null) 
            ? locationRepository.findAll() 
            : locationRepository.findByCabinetId(cabinetId);

        return locations.stream()
            .map(this::enrichLocationDTO)
            .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public LocationDTO getLocationById(Long id) {
        LocationEntity entity = locationRepository.findById(id)
            .orElseThrow(() -> new IllegalArgumentException("Ubicazione non trovata con ID: " + id));
        return enrichLocationDTO(entity);
    }

    @Transactional
    public StockMovementResult moveStock(StockMovementRequest request) {
        LocationEntity source = locationRepository.findById(request.getSourceLocationId())
            .orElseThrow(() -> new IllegalArgumentException("Ubicazione di partenza non trovata"));
        LocationEntity dest = locationRepository.findById(request.getDestLocationId())
            .orElseThrow(() -> new IllegalArgumentException("Ubicazione di destinazione non trovata"));

        int qty = request.getQuantity();

        // 1. Controllo pezzi disponibili
        if (source.getQuantity() == null || source.getQuantity() < qty) {
            return StockMovementResult.builder()
                .success(false)
                .message("L'ubicazione di partenza contiene meno pezzi del necessario (disponibili: " 
                    + (source.getQuantity() != null ? source.getQuantity() : 0) + ", richiesti: " + qty + ")")
                .sourceLocation(enrichLocationDTO(source))
                .destLocation(enrichLocationDTO(dest))
                .build();
        }

        // Recupero info prodotto per ingombro
        ProductDTO product = fetchProduct(source.getProductId());
        int unitIngombro = (product != null && product.getIngombro() != null) ? product.getIngombro() : 1;
        int requiredIngombro = qty * unitIngombro;

        // 2. Controllo coerenza Prodotto in destinazione
        if (dest.getQuantity() != null && dest.getQuantity() > 0) {
            if (!Objects.equals(dest.getProductId(), source.getProductId())) {
                return StockMovementResult.builder()
                    .success(false)
                    .message("Le due ubicazioni contengono prodotti diversi")
                    .sourceLocation(enrichLocationDTO(source))
                    .destLocation(enrichLocationDTO(dest))
                    .build();
            }
            // 3. Controllo coerenza Cliente in destinazione
            if (!Objects.equals(dest.getCustomerId(), source.getCustomerId())) {
                return StockMovementResult.builder()
                    .success(false)
                    .message("Le due ubicazioni contengono prodotti di clienti diversi")
                    .sourceLocation(enrichLocationDTO(source))
                    .destLocation(enrichLocationDTO(dest))
                    .build();
            }
        }

        // 4. Controllo ingombro libero in destinazione
        int destFree = dest.getMaxIngombro() - (dest.getCurrentIngombro() != null ? dest.getCurrentIngombro() : 0);
        if (destFree < requiredIngombro) {
            return StockMovementResult.builder()
                .success(false)
                .message("L'ubicazione di destinazione non ha abbastanza ingombro libero (libero: " 
                    + destFree + ", necessario: " + requiredIngombro + ")")
                .sourceLocation(enrichLocationDTO(source))
                .destLocation(enrichLocationDTO(dest))
                .build();
        }

        // Esecuzione movimentazione
        source.setQuantity(source.getQuantity() - qty);
        source.setCurrentIngombro(source.getCurrentIngombro() - requiredIngombro);
        if (source.getQuantity() == 0) {
            source.setProductId(null);
            source.setCustomerId(null);
            source.setCurrentIngombro(0);
        }

        dest.setQuantity((dest.getQuantity() != null ? dest.getQuantity() : 0) + qty);
        dest.setCurrentIngombro((dest.getCurrentIngombro() != null ? dest.getCurrentIngombro() : 0) + requiredIngombro);
        dest.setProductId(source.getProductId() != null ? source.getProductId() : dest.getProductId());
        dest.setCustomerId(source.getCustomerId() != null ? source.getCustomerId() : dest.getCustomerId());

        locationRepository.save(source);
        locationRepository.save(dest);

        return StockMovementResult.builder()
            .success(true)
            .message("Movimentazione di " + qty + " pezzi completata con successo!")
            .sourceLocation(enrichLocationDTO(source))
            .destLocation(enrichLocationDTO(dest))
            .build();
    }

    @Transactional(readOnly = true)
    public NearestLocationResponse findNearestLocation(NearestLocationRequest request) {
        LocationEntity source = locationRepository.findById(request.getSourceLocationId())
            .orElseThrow(() -> new IllegalArgumentException("Ubicazione sorgente non trovata"));

        if (source.getQuantity() == null || source.getQuantity() == 0 || source.getProductId() == null) {
            return NearestLocationResponse.builder()
                .sourceLocationId(source.getId())
                .message("L'ubicazione sorgente è vuota")
                .build();
        }

        ProductDTO product = fetchProduct(source.getProductId());
        int unitIngombro = (product != null && product.getIngombro() != null) ? product.getIngombro() : 1;
        int requiredIngombro = request.getQuantity() * unitIngombro;

        CabinetEntity sourceCabinet = cabinetRepository.findById(source.getCabinetId()).orElseThrow();

        List<LocationEntity> allLocations = locationRepository.findAll();

        LocationEntity bestCandidate = null;
        int minDistance = Integer.MAX_VALUE;

        for (LocationEntity loc : allLocations) {
            if (loc.getId().equals(source.getId())) continue;

            int freeSpace = loc.getMaxIngombro() - (loc.getCurrentIngombro() != null ? loc.getCurrentIngombro() : 0);
            if (freeSpace < requiredIngombro) continue;

            if (loc.getQuantity() != null && loc.getQuantity() > 0) {
                if (!Objects.equals(loc.getProductId(), source.getProductId())) continue;
                if (!Objects.equals(loc.getCustomerId(), source.getCustomerId())) continue;
            }

            CabinetEntity targetCabinet = cabinetRepository.findById(loc.getCabinetId()).orElse(null);
            if (targetCabinet == null) continue;

            int distance = Math.abs(sourceCabinet.getRow() - targetCabinet.getRow()) 
                         + Math.abs(sourceCabinet.getCol() - targetCabinet.getCol());

            if (distance < minDistance) {
                minDistance = distance;
                bestCandidate = loc;
            }
        }

        if (bestCandidate == null) {
            return NearestLocationResponse.builder()
                .sourceLocationId(source.getId())
                .message("Nessuna ubicazione idonea disponibile per contenere " + request.getQuantity() + " pezzi")
                .build();
        }

        return NearestLocationResponse.builder()
            .sourceLocationId(source.getId())
            .nearestLocation(enrichLocationDTO(bestCandidate))
            .distance(minDistance)
            .message("Ubicazione più vicina identificata con distanza di Manhattan d=" + minDistance)
            .build();
    }

    private CabinetDTO toCabinetDTO(CabinetEntity entity) {
        return CabinetDTO.builder()
            .id(entity.getId())
            .row(entity.getRow())
            .col(entity.getCol())
            .name(entity.getName())
            .build();
    }

    private LocationDTO enrichLocationDTO(LocationEntity entity) {
        CabinetEntity cabinet = cabinetRepository.findById(entity.getCabinetId()).orElse(null);

        String productName = null;
        if (entity.getProductId() != null) {
            ProductDTO p = fetchProduct(entity.getProductId());
            productName = (p != null) ? p.getName() : "Prodotto #" + entity.getProductId();
        }

        String customerName = null;
        if (entity.getCustomerId() != null) {
            CustomerDTO c = fetchCustomer(entity.getCustomerId());
            customerName = (c != null) ? c.getCompany() + " (" + c.getName() + ")" : "Cliente #" + entity.getCustomerId();
        }

        return LocationDTO.builder()
            .id(entity.getId())
            .cabinetId(entity.getCabinetId())
            .cabinetRow(cabinet != null ? cabinet.getRow() : null)
            .cabinetCol(cabinet != null ? cabinet.getCol() : null)
            .maxIngombro(entity.getMaxIngombro())
            .currentIngombro(entity.getCurrentIngombro())
            .productId(entity.getProductId())
            .productName(productName)
            .customerId(entity.getCustomerId())
            .customerName(customerName)
            .quantity(entity.getQuantity())
            .build();
    }

    private ProductDTO fetchProduct(Long id) {
        if (id == null) return null;
        try {
            return productClient.getProductById(id);
        } catch (Exception e) {
            log.warn("Impossibile recuperare il prodotto via Feign (id: {}): {}", id, e.getMessage());
            return ProductDTO.builder().id(id).name("Prodotto #" + id).ingombro(10).build();
        }
    }

    private CustomerDTO fetchCustomer(Long id) {
        if (id == null) return null;
        try {
            return crmClient.getCustomerById(id);
        } catch (Exception e) {
            log.warn("Impossibile recuperare il cliente via Feign (id: {}): {}", id, e.getMessage());
            return CustomerDTO.builder().id(id).company("Cliente #" + id).build();
        }
    }
}
