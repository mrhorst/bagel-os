const setupAutoSubmitForms = () => {
  document.querySelectorAll("[data-auto-submit-form]").forEach((form) => {
    if (form.dataset.autoSubmitReady === "true") return;

    const submitButton = form.querySelector("[data-filter-submit]");
    const asyncFrame = form.dataset.asyncFrame;
    let timeoutId;
    let controller;

    const submitSoon = (delay) => {
      window.clearTimeout(timeoutId);
      timeoutId = window.setTimeout(() => {
        if (form.requestSubmit) {
          form.requestSubmit(submitButton);
        } else {
          form.submit();
        }
      }, delay);
    };

    form.addEventListener("submit", (event) => {
      if (!asyncFrame) return;

      event.preventDefault();
      controller?.abort();
      controller = new AbortController();

      const url = new URL(form.action, window.location.origin);
      url.search = new URLSearchParams(new FormData(form)).toString();
      form.setAttribute("aria-busy", "true");

      fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        signal: controller.signal
      })
        .then((response) => {
          if (!response.ok) throw new Error(`Request failed with ${response.status}`);
          return response.text();
        })
        .then((html) => {
          const documentFragment = new DOMParser().parseFromString(html, "text/html");
          const currentFrames = document.querySelectorAll(`[data-async-frame="${asyncFrame}"]`);
          const newFrames = documentFragment.querySelectorAll(`[data-async-frame="${asyncFrame}"]`);

          currentFrames.forEach((frame, index) => {
            const replacement = newFrames[index];
            if (replacement) frame.replaceWith(replacement);
          });

          window.history.replaceState({}, "", url.toString());
        })
        .catch((error) => {
          if (error.name !== "AbortError") form.submit();
        })
        .finally(() => {
          form.removeAttribute("aria-busy");
        });
    });

    form.querySelectorAll("input[type='search'], input[type='text']").forEach((input) => {
      input.addEventListener("input", () => submitSoon(300));
    });

    form.querySelectorAll("select, input[type='checkbox']").forEach((input) => {
      input.addEventListener("change", () => submitSoon(0));
    });

    form.dataset.autoSubmitReady = "true";
  });
};

const setupChartSwitchers = () => {
  document.querySelectorAll("[data-chart-switcher]").forEach((switcher) => {
    if (switcher.dataset.chartSwitcherReady === "true") return;

    const controls = Array.from(switcher.querySelectorAll("[data-chart-mode]"));
    const summaries = Array.from(switcher.querySelectorAll("[data-chart-summary]"));
    const insights = Array.from(switcher.querySelectorAll("[data-chart-insight]"));
    const panels = Array.from(switcher.querySelectorAll("[data-chart-panel]"));

    const setMode = (mode, href) => {
      controls.forEach((control) => {
        const active = control.dataset.chartMode === mode;
        control.classList.toggle("active", active);
        control.setAttribute("aria-selected", active ? "true" : "false");
      });

      summaries.forEach((summary) => {
        summary.hidden = summary.dataset.chartSummary !== mode;
      });

      insights.forEach((insight) => {
        insight.hidden = insight.dataset.chartInsight !== mode;
      });

      panels.forEach((panel) => {
        panel.hidden = panel.dataset.chartPanel !== mode;
      });

      if (href) window.history.replaceState({}, "", href);
    };

    controls.forEach((control) => {
      control.addEventListener("click", (event) => {
        event.preventDefault();
        setMode(control.dataset.chartMode, control.href);
      });
    });

    setMode(switcher.dataset.initialChartMode || "package_price");
    switcher.dataset.chartSwitcherReady = "true";
  });
};

document.addEventListener("DOMContentLoaded", () => {
  setupAutoSubmitForms();
  setupChartSwitchers();
});
