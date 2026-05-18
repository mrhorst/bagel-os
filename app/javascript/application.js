// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "Chart.bundle"
import "chartjs-plugin-datalabels"

const registerChartDataLabels = () => {
  if (!window.Chart || !window.ChartDataLabels) return

  window.Chart.register(window.ChartDataLabels)
  window.Chart.defaults.plugins.datalabels.display = false
  window.Chart.defaults.plugins.datalabels.formatter = (value, context) => {
    if (value === null || value === undefined) return null

    const options = context.chart?.options?.plugins?.datalabels || {}
    const numericValue = typeof value === "object" ? value.y ?? value.r : value
    const number = Number(numericValue)
    if (!Number.isFinite(number)) return null

    const decimals = options.valueDecimals ?? (options.valuePrefix ? 2 : 4)
    const formatted = new Intl.NumberFormat("en-US", {
      minimumFractionDigits: options.valuePrefix ? decimals : 0,
      maximumFractionDigits: decimals
    }).format(number)

    return `${options.valuePrefix || ""}${formatted}${options.valueSuffix || ""}`
  }
}

registerChartDataLabels()

import "chartkick"
import "controllers"
