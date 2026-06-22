module ReportsHelper
  # Plain-language description of a report export, used on the Reports index so
  # the "Description" column actually describes the file rather than repeating
  # its name. Delegates to the exporter, which owns the report catalog.
  def report_description(report)
    Purchasing::ReportExporter.description_for(report)
  end
end
