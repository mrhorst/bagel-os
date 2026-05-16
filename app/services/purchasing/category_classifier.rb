module Purchasing
  class CategoryClassifier
    RULES = {
      "Bakery ingredients" => /\b(BAGEL|BRD|BREAD|BISCUIT|CORN BREAD|COOKIE|DAISY|TOAST|MUFFN|PANCAK|WAFFLE)\b/i,
      "Cream cheese / spreads" => /\b(CHS CREAM|CHS CRM|CREAM CHEESE|CRM JF|CREAM BULK|SOFT\s+5LB)\b/i,
      "Eggs" => /\bEGGS?\b/i,
      "Dairy" => /\b(MILK|HALF&HALF|H&H|CREAMER|CREAM JF|BTR|BUTTER|CHS|CHEESE|MOZ|SWISS)\b/i,
      "Meat" => /\b(BACON|HAM|PASTRAMI|CORNED|TRKY|TURKEY|TKY|BURGER|CHIX|SAU\s|SAUS|SAUSAGE|BF\s)\b/i,
      "Fish / seafood" => /\b(TUNA|FISH|SEAFOOD|SALMON|NOVA)\b/i,
      "Produce" => /\b(PROD|PD\s|LETTUCE|POTATO|MUSHROOM|MUSH|TOMATO|ONION|CELLO|BLACKBERRIES|BLUEBERRIES|STRAWBERRIES)\b/i,
      "Beverages" => /\b(JUICE|JCE|OJ|COKE|GUARANA|WATER|BEV|DRINK|ZEPHYRHILLS)\b/i,
      "Dry goods" => /\b(GRITS|OATS|ELBOWS|FLOUR|SUGAR|SALT|CINNAMON|PAPRIKA|SEAS|OLD BAY|SPICE|BS\s)\b/i,
      "Frozen" => /\b(FZ|FF\s|FROZEN)\b/i,
      "Condiments" => /\b(MAYO|KETCHUP|MUSTARD|SAUCE|SYRUP|JELLY|JAM|MARMLD|RELISH|OIL|VINEGAR|DRESS|DRESSING|GRAVY|PICKLE|NUTELLA|SAUERKRAUT|SPLENDA|SWEET & LOW)\b/i,
      "Coffee / tea" => /\b(COFFEE|TEA)\b/i,
      "Paper goods" => /\b(PAPER|TOWEL|NAPKIN|BAG WHT|CHECKS|ROLL|WAX PPR|WAX)\b/i,
      "Packaging" => /\b(LID|CUP|CONTAINER|CONT|CLAM|LINER|SOUF|STRAW|STRW|WRAP|FOIL|PLATE|BOWL|LABEL|BAG POLY|KIT FKSN|CUTLERY|SMILEFACE)\b|BAG PL/i,
      "Cleaning supplies" => /\b(DEGR|DEGRSR|CLEAN|SOAP|DIAL|GLOVE|SANIT|BLEACH|DETERGENT|PALMOLIVE|GRILL BRICK|SPONGE|SCRUBBER|SPRAY BOTTLE|TOILET BRUSH|KLEEN PAIL|GLADE)\b/i,
      "Smallwares" => /\b(PAD GRIDDLE|HAIRNET|APRON|CHEESE CLOTH|UTENSIL|KNIFE|PAN|COFFEE POT|FUNNEL|GRAVY BOAT|MEASURE|RACK|SCOOP|SQEZ BOT|TRAY|BUS BOX)\b/i,
      "Equipment / maintenance" => /\b(EQUIP|REPAIR|MAINT|FILTER)\b/i
    }.freeze

    def category_for(description)
      name = RULES.find { |_category, pattern| description.to_s.match?(pattern) }&.first
      ProductCategory.find_by(name: name) || ProductCategory.unknown
    end
  end
end
