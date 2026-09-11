package com.example.ttfcloud_esame.wmsservice.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "cabinets")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CabinetEntity {

    @Id
    private Long id;

    @Column(name = "grid_row")
    private Integer row;

    @Column(name = "grid_col")
    private Integer col;

    private String name;
}
