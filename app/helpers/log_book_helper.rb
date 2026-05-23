module LogBookHelper
  # Confirmation copy shown before archiving a Log Section. Loud when the
  # section has been used; gentler when it hasn't.
  def archive_confirm_message(section, usage_count)
    if usage_count.positive?
      "Archive “#{section.title}”? It's been used in #{pluralize(usage_count, 'entry')}. " \
        "It will disappear from tomorrow's form; past responses are kept."
    else
      "Archive “#{section.title}”? It will disappear from new days."
    end
  end
end
