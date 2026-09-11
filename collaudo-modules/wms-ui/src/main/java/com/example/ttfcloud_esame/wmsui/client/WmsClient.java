package com.example.ttfcloud_esame.wmsui.client;

import java.util.List;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;

import com.example.ttfcloud_esame.common.dto.CabinetDTO;
import com.example.ttfcloud_esame.common.dto.LocationDTO;
import com.example.ttfcloud_esame.common.dto.NearestLocationRequest;
import com.example.ttfcloud_esame.common.dto.NearestLocationResponse;
import com.example.ttfcloud_esame.common.dto.StockMovementRequest;
import com.example.ttfcloud_esame.common.dto.StockMovementResult;

@FeignClient(name = "WMS-SERVICE")
public interface WmsClient {

    @GetMapping("/api/wms/cabinets")
    List<CabinetDTO> getCabinets();

    @GetMapping("/api/wms/locations")
    List<LocationDTO> getLocations(@RequestParam(value = "cabinetId", required = false) Long cabinetId);

    @GetMapping("/api/wms/locations/{id}")
    LocationDTO getLocationById(@PathVariable("id") Long id);

    @PostMapping("/api/wms/movements")
    StockMovementResult moveStock(@RequestBody StockMovementRequest request);

    @PostMapping("/api/wms/nearest-location")
    NearestLocationResponse findNearestLocation(@RequestBody NearestLocationRequest request);
}
