package com.example.ttfcloud_esame.wmsui;

import java.util.List;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import com.example.ttfcloud_esame.common.dto.CabinetDTO;
import com.example.ttfcloud_esame.common.dto.LocationDTO;
import com.example.ttfcloud_esame.common.dto.NearestLocationRequest;
import com.example.ttfcloud_esame.common.dto.NearestLocationResponse;
import com.example.ttfcloud_esame.common.dto.StockMovementRequest;
import com.example.ttfcloud_esame.common.dto.StockMovementResult;
import com.example.ttfcloud_esame.wmsui.client.WmsClient;

import lombok.RequiredArgsConstructor;

@Controller
@RequiredArgsConstructor
public class WmsUiController {

    private final WmsClient wmsClient;

    @GetMapping("/")
    public String dashboard(
        @RequestParam(required = false) Long cabinetId,
        Model model
    ) {
        try {
            List<CabinetDTO> cabinets = wmsClient.getCabinets();
            model.addAttribute("cabinets", cabinets);
            model.addAttribute("selectedCabinetId", cabinetId);

            List<LocationDTO> locations = wmsClient.getLocations(cabinetId);
            model.addAttribute("locations", locations);

            if (!model.containsAttribute("movementRequest")) {
                model.addAttribute("movementRequest", new StockMovementRequest());
            }
            if (!model.containsAttribute("nearestRequest")) {
                model.addAttribute("nearestRequest", new NearestLocationRequest());
            }
        } catch (Exception e) {
            model.addAttribute("errorMessage", "Errore nella comunicazione con il cluster WMS: " + e.getMessage());
        }

        return "wms-dashboard";
    }

    @PostMapping("/movement")
    public String executeMovement(
        @ModelAttribute("movementRequest") StockMovementRequest request,
        RedirectAttributes redirectAttributes
    ) {
        try {
            StockMovementResult result = wmsClient.moveStock(request);
            if (result.isSuccess()) {
                redirectAttributes.addFlashAttribute("successMessage", result.getMessage());
            } else {
                redirectAttributes.addFlashAttribute("errorMessage", result.getMessage());
            }
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("errorMessage", "Errore nell'esecuzione dello spostamento: " + e.getMessage());
        }
        return "redirect:/";
    }

    @PostMapping("/nearest-location")
    public String calculateNearestLocation(
        @ModelAttribute("nearestRequest") NearestLocationRequest request,
        RedirectAttributes redirectAttributes
    ) {
        try {
            NearestLocationResponse response = wmsClient.findNearestLocation(request);
            redirectAttributes.addFlashAttribute("nearestResponse", response);
        } catch (Exception e) {
            redirectAttributes.addFlashAttribute("errorMessage", "Errore nel calcolo dell'ubicazione vicina: " + e.getMessage());
        }
        return "redirect:/";
    }
}
