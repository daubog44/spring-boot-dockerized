package com.example.ttfcloud_esame.ui;

import java.util.List;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import com.example.ttfcloud_esame.common.dto.StoredSuggestionResponse;
import com.example.ttfcloud_esame.ui.SuggestionFacade.SuggestionWorkflowResult;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@Controller
@RequiredArgsConstructor
public class UiController {

    private final SuggestionFacade suggestionFacade;

    @GetMapping("/")
    public String home(Model model) {
        if (!model.containsAttribute("form")) {
            model.addAttribute("form", new SuggestionForm());
        }
        if (!model.containsAttribute("history")) {
            model.addAttribute("history", safeHistory());
        }
        if (!model.containsAttribute("errorMessage")) {
            model.addAttribute("errorMessage", null);
        }

        return "event-suggestion";
    }

    @PostMapping("/suggest")
    public String suggest(
        @Valid @ModelAttribute("form") SuggestionForm form,
        BindingResult bindingResult,
        RedirectAttributes redirectAttributes
    ) {
        redirectAttributes.addFlashAttribute("form", form);

        if (bindingResult.hasErrors()) {
            applyError(redirectAttributes, "Controlla i dati inseriti nel form");
            return "redirect:/";
        }

        try {
            SuggestionWorkflowResult result = suggestionFacade.pickSuggestion(form);
            applyResult(redirectAttributes, result);
        } catch (Exception exception) {
            applyError(redirectAttributes, exception.getMessage());
        }

        return "redirect:/";
    }

    @PostMapping("/partial/suggest")
    public String suggestPartial(
        @Valid @ModelAttribute("form") SuggestionForm form,
        BindingResult bindingResult,
        Model model
    ) {
        model.addAttribute("form", form);

        if (bindingResult.hasErrors()) {
            applyError(model, "Controlla i dati inseriti nel form");
            return "event-suggestion :: suggestionFeedback";
        }

        try {
            SuggestionWorkflowResult result = suggestionFacade.pickSuggestion(form);
            applyResult(model, result);
        } catch (Exception exception) {
            applyError(model, exception.getMessage());
        }

        return "event-suggestion :: suggestionFeedback";
    }

    private void applyResult(Model model, SuggestionWorkflowResult result) {
        model.addAttribute("errorMessage", null);
        model.addAttribute("selectedEvent", result.selectedEvent());
        model.addAttribute("selectedIndex", result.selectedIndex() + 1);
        model.addAttribute("availableCount", result.availableCount());
        model.addAttribute("history", result.history());
    }

    private void applyResult(RedirectAttributes redirectAttributes, SuggestionWorkflowResult result) {
        redirectAttributes.addFlashAttribute("errorMessage", null);
        redirectAttributes.addFlashAttribute("selectedEvent", result.selectedEvent());
        redirectAttributes.addFlashAttribute("selectedIndex", result.selectedIndex() + 1);
        redirectAttributes.addFlashAttribute("availableCount", result.availableCount());
        redirectAttributes.addFlashAttribute("history", result.history());
    }

    private void applyError(Model model, String errorMessage) {
        model.addAttribute("errorMessage", errorMessage);
        model.addAttribute("selectedEvent", null);
        model.addAttribute("history", safeHistory());
    }

    private void applyError(RedirectAttributes redirectAttributes, String errorMessage) {
        redirectAttributes.addFlashAttribute("errorMessage", errorMessage);
        redirectAttributes.addFlashAttribute("history", safeHistory());
    }

    private List<StoredSuggestionResponse> safeHistory() {
        try {
            return suggestionFacade.history();
        } catch (Exception ignored) {
            return List.of();
        }
    }
}
