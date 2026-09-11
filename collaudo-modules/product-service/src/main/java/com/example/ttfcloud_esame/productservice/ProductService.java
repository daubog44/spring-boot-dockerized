package com.example.ttfcloud_esame.productservice;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.ttfcloud_esame.common.dto.ProductDTO;
import com.example.ttfcloud_esame.productservice.persistence.ProductEntity;
import com.example.ttfcloud_esame.productservice.persistence.ProductRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProductService implements CommandLineRunner {

    private final ProductRepository productRepository;

    @Override
    @Transactional
    public void run(String... args) {
        if (productRepository.count() == 0) {
            log.info("Inizializzazione dati di prova per l'Anagrafica Prodotti...");
            productRepository.save(new ProductEntity(101L, "Scatola cartone standard", "Dimensione 30x30x30 cm", 15.00, 10));
            productRepository.save(new ProductEntity(102L, "Pallet legno pesante", "Carico fino a 500kg", 85.00, 50));
            productRepository.save(new ProductEntity(103L, "Contenitore plastico isolato", "Per merci deperibili", 45.00, 25));
            log.info("Popolati 3 prodotti di prova nel DB.");
        }
    }

    @Transactional(readOnly = true)
    public List<ProductDTO> findAll() {
        return productRepository.findAll().stream()
            .map(this::toDTO)
            .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ProductDTO findById(Long id) {
        return productRepository.findById(id)
            .map(this::toDTO)
            .orElseThrow(() -> new IllegalArgumentException("Prodotto non trovato con ID: " + id));
    }

    @Transactional(readOnly = true)
    public List<ProductDTO> search(String query) {
        return productRepository.searchByNameOrDescription(query).stream()
            .map(this::toDTO)
            .collect(Collectors.toList());
    }

    @Transactional
    public ProductDTO save(ProductDTO dto) {
        ProductEntity entity = toEntity(dto);
        ProductEntity saved = productRepository.save(entity);
        return toDTO(saved);
    }

    @Transactional
    public void delete(Long id) {
        if (!productRepository.existsById(id)) {
            throw new IllegalArgumentException("Impossibile cancellare: Prodotto non trovato con ID " + id);
        }
        productRepository.deleteById(id);
    }

    private ProductDTO toDTO(ProductEntity entity) {
        return ProductDTO.builder()
            .id(entity.getId())
            .name(entity.getName())
            .description(entity.getDescription())
            .price(entity.getPrice())
            .ingombro(entity.getIngombro())
            .build();
    }

    private ProductEntity toEntity(ProductDTO dto) {
        return ProductEntity.builder()
            .id(dto.getId())
            .name(dto.getName())
            .description(dto.getDescription())
            .price(dto.getPrice())
            .ingombro(dto.getIngombro())
            .build();
    }
}
