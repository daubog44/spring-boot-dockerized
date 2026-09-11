document.addEventListener("DOMContentLoaded", () => {
    const form = document.getElementById("suggestion-form");
    const feedbackContainer = document.getElementById("form-feedback");
    const panelsContainer = document.getElementById("suggestion-panels");

    if (!form || !feedbackContainer || !panelsContainer) {
        return;
    }

    const submitButton = form.querySelector('button[type="submit"]');
    const defaultLabel = submitButton?.dataset.label || submitButton?.textContent || "Sorteggia evento";

    form.addEventListener("submit", async (event) => {
        event.preventDefault();

        if (!submitButton) {
            return;
        }

        setLoadingState(submitButton, true, defaultLabel);

        try {
            const response = await fetch(form.dataset.asyncAction, {
                method: "POST",
                headers: {
                    "Accept": "text/html",
                    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                    "X-Requested-With": "fetch"
                },
                body: new URLSearchParams(new FormData(form))
            });

            if (!response.ok) {
                throw new Error("Impossibile aggiornare il suggerimento");
            }

            replaceDynamicSections(await response.text());
        } catch (error) {
            renderFallbackError(error instanceof Error ? error.message : "Errore imprevisto");
        } finally {
            setLoadingState(submitButton, false, defaultLabel);
        }
    });

    function replaceDynamicSections(html) {
        const parser = new DOMParser();
        const nextDocument = parser.parseFromString(html, "text/html");
        const nextFeedback = nextDocument.getElementById("form-feedback");
        const nextPanels = nextDocument.getElementById("suggestion-panels");

        if (nextFeedback) {
            document.getElementById("form-feedback")?.replaceWith(nextFeedback);
        }

        if (nextPanels) {
            document.getElementById("suggestion-panels")?.replaceWith(nextPanels);
        }
    }

    function renderFallbackError(message) {
        const currentFeedback = document.getElementById("form-feedback");
        if (!currentFeedback) {
            return;
        }

        currentFeedback.innerHTML = `
            <div class="rounded-3xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                ${escapeHtml(message)}
            </div>
        `;
    }

    function setLoadingState(button, loading, defaultLabel) {
        button.disabled = loading;
        button.classList.toggle("opacity-70", loading);
        button.classList.toggle("cursor-wait", loading);
        button.textContent = loading ? "Caricamento..." : defaultLabel;
    }

    function escapeHtml(value) {
        return value
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll("\"", "&quot;")
            .replaceAll("'", "&#39;");
    }
});
