module Purchasing
  class ProductNameInterpreter
    Result = Struct.new(
      :canonical_name,
      :confidence_score,
      :auto_review,
      :family_group,
      :basis,
      keyword_init: true
    ) do
      def auto_review?
        auto_review
      end

      def family_group?
        family_group
      end
    end

    RULES = [
      [ /\bTUNA\b/i, "Tuna", "raw name contains TUNA" ],
      [ /\bEGGS?\b/i, "Eggs", "raw name contains EGG/EGGS" ],
      [ /\b(CHS CREAM|CHS CRM|CREAM CHEESE|CREAM BULK)\b/i, "Cream Cheese", "cream cheese shorthand" ],
      [ /\b(CHS AM|CHS AMER|CHS AMR)\b.*\b(WHT|WHITE)\b/i, "American Cheese White", "white American cheese shorthand" ],
      [ /\b(CHS AM|CHS AMER|CHS AMR)\b.*\b(YL|YELLOW)\b/i, "American Cheese Yellow", "yellow American cheese shorthand" ],
      [ /\b(CHS AM|CHS AMER|CHS AMR)\b/i, "American Cheese", "American cheese shorthand; color not visible" ],
      [ /\bCHS CHED\b/i, "Cheddar Cheese", "cheddar cheese shorthand" ],
      [ /\bFETA\b/i, "Feta Cheese", "feta cheese shorthand" ],
      [ /\b(CHS MOZ|CHS MOZZ)\b/i, "Mozzarella Cheese", "mozzarella cheese shorthand" ],
      [ /\b(CHS SWISS|CHZ SWISS)\b/i, "Swiss Cheese", "Swiss cheese shorthand" ],
      [ /\bTKY BACON\b/i, "Turkey Bacon", "turkey bacon shorthand" ],
      [ /\bBACON\b/i, "Bacon", "raw name contains BACON" ],
      [ /\bPASTRAMI\b/i, "Pastrami", "raw name contains PASTRAMI" ],
      [ /\b(BF CORNED|CORNED BEEF)\b/i, "Corned Beef", "corned beef shorthand" ],
      [ /\bBURGER\b/i, "Burger Patties", "burger patty shorthand" ],
      [ /\bCHIX BREAST\b/i, "Chicken Breast", "chicken breast shorthand" ],
      [ /\b(FZ SAU|FZSAU|SAUSAGE|SAU)\b.*\b(PAT|PATY|PATTY|PATTIES)\b/i, "Sausage Patties", "sausage patty shorthand" ],
      [ /\b(FZ SAUS|FZ SAU|SAUSAGE|SAUS)\b.*\b(LK|LINK|LINKS)\b/i, "Sausage Links", "sausage link shorthand" ],
      [ /\b(FZ SAU|FZSAU|FZ SAUS|SAUSAGE|SAU PAT)/i, "Sausage", "sausage shorthand; format not visible" ],
      [ /\bHAM\b/i, "Ham", "raw name contains HAM" ],
      [ /\bTRKY\b/i, "Turkey", "turkey shorthand" ],
      [ /\bSMK NOVA SALMON\b/i, "Nova Salmon", "nova salmon shorthand" ],
      [ /\bBRD RYE\b/i, "Rye Bread", "rye bread shorthand" ],
      [ /\bBRD TEXAS TOAST\b/i, "Texas Toast", "Texas toast shorthand" ],
      [ /\bBRD WHOLE WHT\b/i, "Whole Wheat Bread", "whole wheat bread shorthand" ],
      [ /\bBRD WONDER WHITE\b/i, "White Bread", "white bread shorthand" ],
      [ /\bFZ CQ BTMK BISCUIT\b/i, "Buttermilk Biscuits", "buttermilk biscuit shorthand" ],
      [ /\bFZ ENG MUFFIN\b/i, "English Muffins", "English muffin shorthand" ],
      [ /\bCHEESE CLOTH\b/i, "Cheese Cloth", "cheese cloth shorthand" ],
      [ /\bDAISY BLUBRY MUFFN\b/i, "Blueberry Muffins", "blueberry muffin shorthand" ],
      [ /\bDAISY CORN BREAD\b/i, "Corn Bread", "corn bread shorthand" ],
      [ /\bDAISY B&W COOKIE\b/i, "Black and White Cookies", "black and white cookie shorthand" ],
      [ /\bPF MILANO COOKIE\b/i, "Milano Cookies", "Milano cookie shorthand" ],
      [ /\bFF BIGC.*CRINKL\b/i, "Crinkle Cut Fries", "crinkle cut fry shorthand" ],
      [ /\bFLOUR\b/i, "Flour", "raw name contains FLOUR" ],
      [ /\b(PANCAK|WAFFLE MX)\b/i, "Pancake and Waffle Mix", "pancake/waffle mix shorthand" ],
      [ /\bGRITS\b/i, "Grits", "raw name contains GRITS" ],
      [ /\bOATS\b/i, "Oats", "raw name contains OATS" ],
      [ /\bPS ELBOWS\b/i, "Elbow Pasta", "elbow pasta shorthand" ],
      [ /\bSUGAR\b/i, "Sugar", "raw name contains SUGAR" ],
      [ /\bSALT\b/i, "Salt", "raw name contains SALT" ],
      [ /\bCINNAMON\b/i, "Cinnamon", "raw name contains CINNAMON" ],
      [ /\bPAPRIKA\b/i, "Paprika", "raw name contains PAPRIKA" ],
      [ /\bOLD BAY\b/i, "Old Bay Seasoning", "Old Bay seasoning shorthand" ],
      [ /\b(MILK OAT|OAT ORIG)\b/i, "Oat Milk", "oat milk shorthand" ],
      [ /\b(HALF&HALF|CRM H&H)\b/i, "Half and Half", "half and half shorthand" ],
      [ /\bCREAM JF 40%/i, "Heavy Cream", "heavy cream shorthand" ],
      [ /\bCREAMER\b/i, "Creamer", "raw name contains CREAMER" ],
      [ /\bBTR\b/i, "Butter", "butter shorthand" ],
      [ /\bCOKE CLASSIC\b/i, "Coke Classic", "Coke Classic shorthand" ],
      [ /\bCOKE ZERO\b/i, "Coke Zero", "Coke Zero shorthand" ],
      [ /\bGUARANA\b/i, "Guarana Soda", "Guarana soda shorthand" ],
      [ /\b(MM ORANGE JUICE|TROP OJ)\b/i, "Orange Juice", "orange juice shorthand" ],
      [ /\bTROP APPLE JCE\b/i, "Apple Juice", "apple juice shorthand" ],
      [ /\bWATER\b/i, "Bottled Water", "raw name contains WATER" ],
      [ /\b(MAYO|PC MAYO)\b/i, "Mayonnaise", "mayo shorthand" ],
      [ /\bKETCHUP\b/i, "Ketchup", "raw name contains KETCHUP" ],
      [ /\bMUSTARD\b/i, "Mustard", "raw name contains MUSTARD" ],
      [ /\b(JELLY|JAM)\b/i, "Jelly and Jam", "jelly/jam shorthand" ],
      [ /\bMARMLD\b/i, "Marmalade", "marmalade shorthand" ],
      [ /\bSYRUP\b/i, "Syrup", "raw name contains SYRUP" ],
      [ /\bOIL\b/i, "Oil", "raw name contains OIL" ],
      [ /\bDRESS CRMY CAESAR\b/i, "Caesar Dressing", "Caesar dressing shorthand" ],
      [ /\bWHITE VINEGAR\b/i, "White Vinegar", "white vinegar shorthand" ],
      [ /\bSAUCE TOMATO\b/i, "Tomato Sauce", "tomato sauce shorthand" ],
      [ /\bSAUCE CHOCOLATE\b/i, "Chocolate Sauce", "chocolate sauce shorthand" ],
      [ /\bSAUERKRAUT\b/i, "Sauerkraut", "raw name contains SAUERKRAUT" ],
      [ /\bNUTELLA\b/i, "Nutella", "raw name contains NUTELLA" ],
      [ /\bSPLENDA\b/i, "Splenda", "raw name contains SPLENDA" ],
      [ /\bSWEET & LOW\b/i, "Sweet and Low", "Sweet and Low shorthand" ],
      [ /\bPD BLACKBERRIES\b/i, "Blackberries", "blackberry produce shorthand" ],
      [ /\bPD BLUEBERRIES\b/i, "Blueberries", "blueberry produce shorthand" ],
      [ /\bPD STRAWBERRIES\b/i, "Strawberries", "strawberry produce shorthand" ],
      [ /\b(PROD AVOCADO)\b/i, "Avocados", "avocado produce shorthand" ],
      [ /\bPROD CABBAGE\b/i, "Cabbage", "cabbage produce shorthand" ],
      [ /\bPROD CARROT\b/i, "Carrots", "carrot produce shorthand" ],
      [ /\bPROD CELLO LETTUCE\b/i, "Lettuce", "lettuce produce shorthand" ],
      [ /\bPROD GARLIC\b/i, "Peeled Garlic", "peeled garlic produce shorthand" ],
      [ /\bPROD GREEN ONION\b/i, "Green Onions", "green onion produce shorthand" ],
      [ /\bPROD LEMON\b/i, "Lemons", "lemon produce shorthand" ],
      [ /\bPROD ONION\b/i, "Onions", "onion produce shorthand" ],
      [ /\bPROD PARS\b/i, "Parsley", "parsley produce shorthand" ],
      [ /\bPROD POTATO\b/i, "Potatoes", "potato produce shorthand" ],
      [ /\b(PROD SPINACH|FZ SPINACH)\b/i, "Spinach", "spinach shorthand" ],
      [ /\bPROD TOFU\b/i, "Tofu", "tofu produce shorthand" ],
      [ /\bPROD TOMATO\b/i, "Tomatoes", "tomato produce shorthand" ],
      [ /\b(PD MUSH|MUSHROOM)\b/i, "Mushrooms", "mushroom shorthand" ],
      [ /\bBAG WHT\b/i, "White Paper Bags", "white bag shorthand" ],
      [ /\bBAG POLY BREAD\b/i, "Poly Bread Bags", "poly bread bag shorthand" ],
      [ /SMILEFACE/i, "Smile Face Bags", "smile face bag shorthand" ],
      [ /\bGLOVE NITRL\b/i, "Nitrile Gloves", "nitrile glove shorthand" ],
      [ /\bGLOVE POW LATEX\b/i, "Latex Gloves", "latex glove shorthand" ],
      [ /\bAPRON\b/i, "Aprons", "raw name contains APRON" ],
      [ /\bHOT.*CUP|CUP HOT\b/i, "Hot Cups", "hot cup shorthand" ],
      [ /\bCUP SFL|CUP SAUCE\b/i, "Portion Cups", "portion cup shorthand" ],
      [ /\bCUP FM\b/i, "Foam Cups", "foam cup shorthand" ],
      [ /\bLID.*SOUF|LID SFL\b/i, "Portion Cup Lids", "portion cup lid shorthand" ],
      [ /\bCONT FM HNG\b/i, "Foam Hinged Containers", "foam hinged container shorthand" ],
      [ /\bLINER\b/i, "Liners", "raw name contains LINER" ],
      [ /\bNAPKIN\b/i, "Napkins", "raw name contains NAPKIN" ],
      [ /\bTOWEL ROLL\b/i, "Paper Towels", "paper towel roll shorthand" ],
      [ /\bTOWEL TERRY|TERRY TOWEL|MICROFBR TWL\b/i, "Towels", "towel shorthand" ],
      [ /\bWAX\b/i, "Wax Paper", "wax paper shorthand" ],
      [ /\bSTRW\b/i, "Straws", "straw shorthand" ],
      [ /\bLABEL\b/i, "Shelf Life Labels", "shelf life label shorthand" ],
      [ /\bCHECKS\b/i, "Guest Checks", "guest check shorthand" ],
      [ /\bDIAL\b/i, "Hand Soap", "Dial soap shorthand" ],
      [ /\b(PALMOLIVE|DISH)\b/i, "Dish Soap", "dish soap shorthand" ],
      [ /\b(DEGR|DEGRSR)\b/i, "Degreaser", "degreaser shorthand" ],
      [ /\bGRILL BRICK\b/i, "Grill Bricks", "grill brick shorthand" ],
      [ /\bSPONGE|SCRUBBER\b/i, "Scrubbers", "scrubber shorthand" ],
      [ /\bHAIRNET\b/i, "Hairnets", "raw name contains HAIRNET" ],
      [ /\bCUTLERY|DOMINION DNR FORK|DOMINION DNR KNIFE|DOMINION DESSRT SP|KIT FKSN\b/i, "Disposable Cutlery", "cutlery shorthand" ],
      [ /\bBUS BOX\b/i, "Bus Boxes", "bus box shorthand" ],
      [ /\bKLEEN PAIL\b/i, "Cleaning Pails", "cleaning pail shorthand" ],
      [ /\bCOFFEE POT\b/i, "Coffee Pots", "coffee pot shorthand" ],
      [ /\bFUNNEL\b/i, "Funnels", "funnel shorthand" ],
      [ /\bGRAVY BOAT\b/i, "Gravy Boats", "gravy boat shorthand" ],
      [ /\bGRAVY COUNTRY\b/i, "Country Gravy", "country gravy shorthand" ],
      [ /\bMEASURE ALUM\b/i, "Measuring Cups", "measuring cup shorthand" ],
      [ /\bPAD GRIDDLE\b/i, "Griddle Pads", "griddle pad shorthand" ],
      [ /\bRACK PLATE\b/i, "Plate Rack", "plate rack shorthand" ],
      [ /\bSCOOP ALUM\b/i, "Scoops", "scoop shorthand" ],
      [ /\bSPRAY BOTTLE\b/i, "Spray Bottles", "spray bottle shorthand" ],
      [ /\bSQEZ BOT\b/i, "Squeeze Bottles", "squeeze bottle shorthand" ],
      [ /\bTOILET BRUSH\b/i, "Toilet Brushes", "toilet brush shorthand" ],
      [ /\bTOWEL BASKET\b/i, "Basket Weave Towels", "basket weave towel shorthand" ],
      [ /\bTRAY CMTRD\b/i, "Serving Trays", "tray shorthand" ],
      [ /\bFZ VICTORIA BLEND\b/i, "Frozen Vegetable Blend", "frozen vegetable blend shorthand" ],
      [ /\bGLADE\b/i, "Air Freshener", "air freshener shorthand" ],
      [ /\bPANCAK W B\/MILK MX\b/i, "Pancake Mix", "pancake mix shorthand" ],
      [ /\bpickle dill spears\b/i, "Dill Pickles", "plain-language receipt name" ]
    ].freeze

    NOISE_TOKENS = %w[
      CQ JF RD ST CM GMS DB PB FR HNZ ADMRTN QKR LENZ DOMINO HEINZ CLSC
      SUNSET SKYLINE SKY BIGC QUAL BELL ITL DOD KR SMK EFG
    ].freeze

    SIZE_PATTERNS = [
      /\A\d+(?:\.\d+)?(?:LB|LBS|#|OZ|Z|DZ|DZN|CT|MCT|EA|GAL|QT|QRT|PT|PK|PKT|SQYD|SL|SLC|CAN|CANS)\z/i,
      /\A\d+(?:\.\d+)?(?:DZ|DZN)\/CS\z/i,
      /\A\d+\/\d+\z/,
      /\A\d+\/\d+[A-Z0-9.\/-]+\z/i,
      /\A\d+:\d+\z/,
      /\A#\d+\z/,
      /\A\d+M(?:CT)?\z/i,
      /\A\d+X\d+\z/i,
      /\A\d+-\d+[A-Z#]*\z/i
    ].freeze

    def interpret(raw_name)
      cleaned = clean(raw_name)
      rule = RULES.find { |pattern, _canonical_name, _basis| cleaned.match?(pattern) }

      if rule
        _pattern, canonical_name, basis = rule
        Result.new(
          canonical_name: canonical_name,
          confidence_score: 0.95,
          auto_review: true,
          family_group: true,
          basis: basis
        )
      else
        Result.new(
          canonical_name: fallback_name(cleaned),
          confidence_score: 0.55,
          auto_review: false,
          family_group: false,
          basis: "fallback cleanup; needs human confirmation"
        )
      end
    end

    def notes_for(canonical_name:, raw_names:, confidence_score:, basis:)
      names = raw_names.map { |name| clean(name) }.reject(&:blank?).uniq.sort
      examples = names.first(12)
      hidden_count = names.size - examples.size
      variant_words = variant_words(names, canonical_name)

      notes = []
      notes << "Codex inference: normalized as #{canonical_name} from supplier receipt shorthand."
      notes << "Basis: #{basis}."
      notes << "Confidence: #{(confidence_score.to_d * 100).round}%."
      notes << "Raw variations kept as aliases: #{examples.join('; ')}#{hidden_count.positive? ? "; plus #{hidden_count} more" : ""}."
      notes << "Variant words seen: #{variant_words.join(', ')}." if variant_words.any?
      notes << "Package sizes and unit conversions stay on receipt lines; this note does not invent missing units."
      notes.join("\n")
    end

    private

    def clean(value)
      value.to_s.strip.gsub(/\A\*/, "").gsub(/\s+/, " ")
    end

    def fallback_name(cleaned)
      words = cleaned.upcase
        .scan(/[A-Z0-9#&\/.-]+/)
        .reject { |token| noise_token?(token) || size_token?(token) }
        .first(4)

      return cleaned.titleize if words.empty?

      words.join(" ").titleize
    end

    def variant_words(raw_names, canonical_name)
      canonical_tokens = canonical_name.upcase.scan(/[A-Z0-9]+/)

      raw_names.flat_map { |name| name.upcase.scan(/[A-Z0-9#&\/.-]+/) }
        .reject { |token| canonical_tokens.include?(token) || noise_token?(token) || size_token?(token) }
        .uniq
        .sort
        .first(16)
    end

    def noise_token?(token)
      NOISE_TOKENS.include?(token)
    end

    def size_token?(token)
      SIZE_PATTERNS.any? { |pattern| token.match?(pattern) }
    end
  end
end
