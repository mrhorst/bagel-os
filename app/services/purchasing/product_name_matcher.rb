module Purchasing
  class ProductNameMatcher
    Match = ProductMatchDecision

    GUIDE_RULES = [
      [ /\Ahalf n half\z/i, "Half and Half" ],
      [ /\Ahalf-and-half\z/i, "Half and Half" ],
      [ /\Amayo\z/i, "Mayonnaise" ],
      [ /\Aoatmilk\z/i, "Oat Milk" ],
      [ /\Aoatmeal\z/i, "Oats" ],
      [ /\Acheddar\z/i, "Cheddar Cheese" ],
      [ /\Amozzarella\z/i, "Mozzarella Cheese" ],
      [ /\Aswiss cheese\z/i, "Swiss Cheese" ],
      [ /\Abutter\b/i, "Butter" ],
      [ /\Asausage patties\z/i, "Sausage Patties" ],
      [ /\Asausage links\z/i, "Sausage Links" ],
      [ /\Abiscuits\z/i, "Buttermilk Biscuits" ],
      [ /\Afries\z/i, "Crinkle Cut Fries" ],
      [ /\Ascallions\z/i, "Green Onions" ],
      [ /\Ause-first labels\z/i, "Shelf Life Labels" ],
      [ /\Alids (?:2|4|8)oz\z/i, "Portion Cup Lids" ],
      [ /\A(?:stainless steel scrubers|scour pads)\z/i, "Scrubbers" ],
      [ /\Acoke\z/i, "Coke Classic" ],
      [ /\A.*orange marmelade\z/i, "Marmalade" ],
      [ /\A(?:pancake mix|waffle mix)\z/i, "Pancake and Waffle Mix" ],
      [ /\Apaper towel rolls\z/i, "Paper Towels" ],
      [ /\Atrash-can liners\z/i, "Liners" ],
      [ /\Alatex gloves non powdered/i, "Latex Gloves" ],
      [ /\Aair freshner\z/i, "Air Freshener" ]
    ].freeze

    CONTEXT_RULES = [
      { pattern: /\Arye\z/i, subcategory: "Sliced Bread", canonical_name: "Rye Bread" },
      { pattern: /\Awhole wheat\z/i, subcategory: "Sliced Bread", canonical_name: "Whole Wheat Bread" },
      { pattern: /\Awhite bread\z/i, canonical_name: "White Bread" }
    ].freeze

    STOP_WORDS = %w[
      AND OF THE TAKEOUT TABLE BOTTLE PACKETS PACKET BOTTLE MEDIUM JUMBO SMALL LARGE
    ].freeze

    def initialize(products: Product.includes(:product_aliases).all)
      @products = products.to_a
      @canonical_index = index_by_name(@products)
      @alias_index = index_aliases(@products)
      @interpreter = ProductNameInterpreter.new
    end

    def match(raw_name, context: {})
      normalized = normalize(raw_name)
      if (product = canonical_index[normalized])
        return Match.new(product: product, confidence: 0.98, basis: "exact canonical product name", source: "order_guide")
      end

      if (product = alias_index[normalized])
        return Match.new(product: product, confidence: 0.95, basis: "exact raw receipt alias", source: "order_guide")
      end

      if (product = product_for_context_rule(raw_name, context))
        return Match.new(product: product, confidence: 0.94, basis: "order guide section/subcategory rule", source: "order_guide")
      end

      if (product = product_for_rule(raw_name))
        return Match.new(product: product, confidence: 0.93, basis: "plain-language order guide rule", source: "order_guide")
      end

      interpreted_name = interpreter.interpret(raw_name).canonical_name
      if interpreted_name.present? && (product = canonical_index[normalize(interpreted_name)])
        return Match.new(product: product, confidence: 0.92, basis: "receipt shorthand interpreter", source: "order_guide")
      end

      suggested_product, score = closest_product(raw_name)
      Match.new(product: nil, suggested_product: suggested_product, confidence: score, basis: "low-confidence token similarity", source: "order_guide")
    end

    def normalize(value)
      words = value.to_s.upcase
        .gsub("&", " AND ")
        .gsub(/\bHALF\s*(?:N|AND|-AND-)\s*HALF\b/, "HALF AND HALF")
        .gsub(/\bMAYO\b/, "MAYONNAISE")
        .scan(/[A-Z0-9]+/)
        .reject { |word| STOP_WORDS.include?(word) }
        .map { |word| singularize_word(word) }

      words.join(" ")
    end

    private

    attr_reader :products, :canonical_index, :alias_index, :interpreter

    def index_by_name(products)
      products.index_by { |product| normalize(product.canonical_name) }
    end

    def index_aliases(products)
      products.each_with_object({}) do |product, index|
        product.product_aliases.each do |alias_record|
          index[normalize(alias_record.raw_name)] ||= product
        end
      end
    end

    def product_for_rule(raw_name)
      rule = GUIDE_RULES.find { |pattern, _canonical_name| raw_name.to_s.squish.match?(pattern) }
      return unless rule

      _pattern, canonical_name = rule
      canonical_index[normalize(canonical_name)]
    end

    def product_for_context_rule(raw_name, context)
      rule = CONTEXT_RULES.find { |candidate| context_rule_match?(candidate, raw_name, context) }
      return unless rule

      canonical_index[normalize(rule.fetch(:canonical_name))]
    end

    def context_rule_match?(rule, raw_name, context)
      return false unless raw_name.to_s.squish.match?(rule.fetch(:pattern))

      if rule[:section_name].present? && context_value(context, :section_name) != rule[:section_name]
        return false
      end

      if rule[:subcategory].present? && context_value(context, :subcategory) != rule[:subcategory]
        return false
      end

      true
    end

    def context_value(context, key)
      (context[key] || context[key.to_s]).to_s
    end

    def closest_product(raw_name)
      raw_tokens = token_set(raw_name)
      return [ nil, 0 ] if raw_tokens.empty?

      products.map do |product|
        product_tokens = token_set(product.canonical_name)
        next [ product, 0 ] if product_tokens.empty?

        [ product, (raw_tokens & product_tokens).size.to_d / (raw_tokens | product_tokens).size ]
      end.max_by { |_product, score| score } || [ nil, 0 ]
    end

    def token_set(value)
      normalize(value).split.uniq
    end

    def singularize_word(word)
      return word if word.length <= 3
      return word.delete_suffix("IES") + "Y" if word.end_with?("IES")
      return word.delete_suffix("S") if word.end_with?("S")

      word
    end
  end
end
