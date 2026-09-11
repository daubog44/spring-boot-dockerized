package com.example.ttfcloud_esame.wmsservice.persistence;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "locations")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LocationEntity {

    @Id
    private Long id;
    private Long cabinetId;
    private Integer maxIngombro;
    private Integer currentIngombro;
    private Long productId;
    private Long customerId;
    private Integer quantity;
}
