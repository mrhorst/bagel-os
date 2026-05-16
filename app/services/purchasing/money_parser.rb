module Purchasing
  class MoneyParser
    def self.parse(value)
      return if value.blank?

      text = value.to_s.strip
      negative = text.include?("-") || (text.start_with?("(") && text.end_with?(")"))
      cleaned = text.gsub(/[^\d.]/, "")
      return if cleaned.blank?

      amount = BigDecimal(cleaned)
      negative ? -amount : amount
    rescue ArgumentError
      nil
    end
  end
end
