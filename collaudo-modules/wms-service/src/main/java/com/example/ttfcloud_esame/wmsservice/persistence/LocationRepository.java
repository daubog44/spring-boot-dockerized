package com.example.ttfcloud_esame.wmsservice.persistence;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface LocationRepository extends JpaRepository<LocationEntity, Long> {
    List<LocationEntity> findByCabinetId(Long cabinetId);
}
