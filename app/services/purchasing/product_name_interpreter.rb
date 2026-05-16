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
      [ /\bTUNA CHUNK LT\b/i, "Chunk Light Tuna", "chunk light tuna shorthand" ],
      [ /\bTUNA TONGOL\b/i, "Tongol Tuna", "tongol tuna shorthand" ],
      [ /\bTUNA\b/i, "Tuna", "tuna shorthand; variety not visible" ],
      [ /\bEGGS?\b.*\bJMB\b/i, "Jumbo Eggs", "jumbo egg shorthand" ],
      [ /\bEGGS?\b.*\bXLG\b/i, "Extra Large Eggs", "extra large egg shorthand" ],
      [ /\bEGGS?\b.*\bLRG\b/i, "Large Eggs", "large egg shorthand" ],
      [ /\bEGGS?\b.*\bMED\b/i, "Medium Eggs", "medium egg shorthand" ],
      [ /\bEGGS?\b/i, "Eggs", "egg shorthand; size not visible" ],
      [ /\bCHS CREAM BULK\b/i, "Bulk Cream Cheese", "bulk cream cheese shorthand" ],
      [ /\bCHS CREAM LOAF\b/i, "Cream Cheese Loaf", "cream cheese loaf shorthand" ],
      [ /\bCHS CRM\b.*\bSOFT\b/i, "Soft Cream Cheese", "soft cream cheese shorthand" ],
      [ /\b(CHS CREAM|CHS CRM|CREAM CHEESE|CREAM BULK)\b/i, "Cream Cheese", "cream cheese shorthand; format not visible" ],
      [ /\b(CHS AM|CHS AMER|CHS AMR)\b.*\b(WHT|WHITE)\b/i, "American Cheese White", "white American cheese shorthand" ],
      [ /\b(CHS AM|CHS AMER|CHS AMR)\b.*\b(YL|YELLOW)\b/i, "American Cheese Yellow", "yellow American cheese shorthand" ],
      [ /\b(CHS AM|CHS AMER|CHS AMR)\b/i, "American Cheese", "American cheese shorthand; color not visible" ],
      [ /\bCHS CHED\b/i, "Cheddar Cheese", "cheddar cheese shorthand" ],
      [ /\bFETA\b/i, "Feta Cheese", "feta cheese shorthand" ],
      [ /\bCHS MOZ\b.*\bR\/W\b/i, "Whole Milk Mozzarella", "random-weight mozzarella shorthand" ],
      [ /\bCHS MOZZ\b.*\bSLC\b/i, "Sliced Mozzarella", "sliced mozzarella shorthand" ],
      [ /\b(CHS MOZ|CHS MOZZ)\b/i, "Mozzarella Cheese", "mozzarella cheese shorthand; format not visible" ],
      [ /\bCHS SWISS\b.*\bSLIC\b/i, "Sliced Swiss Cheese", "sliced Swiss cheese shorthand" ],
      [ /\bCHZ SWISS\b.*\bSAND CUT\b/i, "Sandwich Cut Swiss Cheese", "sandwich-cut Swiss cheese shorthand" ],
      [ /\b(CHS SWISS|CHZ SWISS)\b/i, "Swiss Cheese", "Swiss cheese shorthand; format not visible" ],
      [ /\bTKY BACON\b/i, "Turkey Bacon", "turkey bacon shorthand" ],
      [ /\bBACON\b.*\bAPLW\b.*\b14\/18\b/i, "Applewood Bacon 14/18", "applewood bacon 14/18 shorthand" ],
      [ /\bBACON\b.*\bAPLW\b.*\b18\/22\b/i, "Applewood Bacon 18/22", "applewood bacon 18/22 shorthand" ],
      [ /\bBACON\b.*\bHICK\b/i, "Hickory Bacon", "hickory bacon shorthand" ],
      [ /\bBACON\b.*\bAPLW\b/i, "Applewood Bacon", "applewood bacon shorthand" ],
      [ /\bBACON\b/i, "Bacon", "bacon shorthand; smoke/flavor not visible" ],
      [ /\bPASTRAMI\b.*\bBLKSTR\b/i, "Blackstrap Pastrami", "blackstrap pastrami shorthand" ],
      [ /\bPASTRAMI\b.*\bCRVPRD\b/i, "Carved Pastrami", "carved pastrami shorthand" ],
      [ /\bPASTRAMI\b/i, "Pastrami", "pastrami shorthand; format not visible" ],
      [ /\bBF CORNED\b.*\bCRVPRD\b/i, "Carved Corned Beef", "carved corned beef shorthand" ],
      [ /\bCORNED BEEF HSH\b/i, "Corned Beef Hash", "corned beef hash shorthand" ],
      [ /\b(BF CORNED|CORNED BEEF)\b/i, "Corned Beef", "corned beef shorthand; format not visible" ],
      [ /\bBURGER\b.*\b2:1\b/i, "Burger Patties 2:1", "burger patty 2:1 shorthand" ],
      [ /\bBURGER\b.*\b3:1\b/i, "Burger Patties 3:1", "burger patty 3:1 shorthand" ],
      [ /\bBURGER\b/i, "Burger Patties", "burger patty shorthand; size not visible" ],
      [ /\bCHIX BREAST\b/i, "Chicken Breast", "chicken breast shorthand" ],
      [ /\b(FZ SAU|FZSAU|SAUSAGE|SAU)\b.*\b(PAT|PATY|PATTY|PATTIES)\b.*\b2OZ\b/i, "Sausage Patties 2 oz", "sausage patty 2 oz shorthand" ],
      [ /\b(FZ SAU|FZSAU|SAUSAGE|SAU)\b.*\b(PAT|PATY|PATTY|PATTIES)\b.*\b1\.6Z\b/i, "Sausage Patties 1.6 oz", "sausage patty 1.6 oz shorthand" ],
      [ /\b(FZ SAU|FZSAU|SAUSAGE|SAU)\b.*\b(PAT|PATY|PATTY|PATTIES)\b/i, "Sausage Patties", "sausage patty shorthand; size not visible" ],
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
      [ /\bPANCAK\b/i, "Pancake Mix", "pancake mix shorthand" ],
      [ /\bWAFFLE MX\b/i, "Waffle Mix", "waffle mix shorthand" ],
      [ /\b(PANCAK|WAFFLE MX)\b/i, "Pancake and Waffle Mix", "pancake/waffle mix shorthand; type not visible" ],
      [ /\bGRITS\b/i, "Grits", "raw name contains GRITS" ],
      [ /\bOATS\b/i, "Oats", "raw name contains OATS" ],
      [ /\bPS ELBOWS\b/i, "Elbow Pasta", "elbow pasta shorthand" ],
      [ /\bSUGAR\b/i, "Sugar", "raw name contains SUGAR" ],
      [ /\bSALT\b/i, "Salt", "raw name contains SALT" ],
      [ /\bCINNAMON\b/i, "Cinnamon", "raw name contains CINNAMON" ],
      [ /\bPAPRIKA\b/i, "Paprika", "raw name contains PAPRIKA" ],
      [ /\bOLD BAY\b/i, "Old Bay Seasoning", "Old Bay seasoning shorthand" ],
      [ /\b(MILK OAT|OAT ORIG)\b/i, "Oat Milk", "oat milk shorthand" ],
      [ /\bCRM H&H\b.*\b360CT\b/i, "Half and Half Creamer Cups", "half and half creamer cup shorthand" ],
      [ /\bHALF&HALF\b.*\bUHT\b/i, "UHT Half and Half", "UHT half and half shorthand" ],
      [ /\b(HALF&HALF|CRM H&H)\b/i, "Half and Half", "half and half shorthand; format not visible" ],
      [ /\bCREAM JF 40%/i, "Heavy Cream", "heavy cream shorthand" ],
      [ /\bCREAMER\b/i, "Creamer", "raw name contains CREAMER" ],
      [ /\bBTR\b.*\bWHPCUP\b/i, "Whipped Butter Cups", "whipped butter cup shorthand" ],
      [ /\bBTR\b.*\bQRTS\b/i, "Butter Quarters", "butter quarter shorthand" ],
      [ /\bOIL WHIRL\b.*\bBTR\b/i, "Whirl Liquid Butter Alternative", "Whirl liquid butter alternative shorthand" ],
      [ /\bOIL BTR ALT\b/i, "Butter Alternative Oil", "butter alternative oil shorthand" ],
      [ /\bBTR\b/i, "Butter", "butter shorthand; format not visible" ],
      [ /\bCOKE CLASSIC\b/i, "Coke Classic", "Coke Classic shorthand" ],
      [ /\bCOKE ZERO\b/i, "Coke Zero", "Coke Zero shorthand" ],
      [ /\bGUARANA\b/i, "Guarana Soda", "Guarana soda shorthand" ],
      [ /\bMM ORANGE JUICE\b/i, "Minute Maid Orange Juice", "Minute Maid orange juice shorthand" ],
      [ /\bTROP OJ\b/i, "Tropicana Orange Juice", "Tropicana orange juice shorthand" ],
      [ /\b(MM ORANGE JUICE|TROP OJ)\b/i, "Orange Juice", "orange juice shorthand; brand not visible" ],
      [ /\bTROP APPLE JCE\b/i, "Apple Juice", "apple juice shorthand" ],
      [ /\bWATER\b/i, "Bottled Water", "raw name contains WATER" ],
      [ /\bPC MAYO\b/i, "Mayonnaise Packets", "mayo packet shorthand" ],
      [ /\bMAYO REAL KR\b/i, "Kraft Mayonnaise", "Kraft mayo shorthand" ],
      [ /\bMAYO REAL CQ\b/i, "Mayonnaise", "gallon mayo shorthand" ],
      [ /\b(MAYO|PC MAYO)\b/i, "Mayonnaise", "mayo shorthand; format not visible" ],
      [ /\bKETCHUP\b.*\b14Z\b/i, "Ketchup Bottle 14 oz", "14 oz ketchup bottle shorthand" ],
      [ /\bKETCHUP\b.*\b20Z\b/i, "Ketchup Bottle 20 oz", "20 oz ketchup bottle shorthand" ],
      [ /\bKETCHUP\b.*\bJUG\b/i, "Ketchup Jug", "ketchup jug shorthand" ],
      [ /\bKETCHUP\b/i, "Ketchup", "ketchup shorthand; format not visible" ],
      [ /\bMUSTARD\b/i, "Mustard", "raw name contains MUSTARD" ],
      [ /\bJELLY GRAPE\b/i, "Grape Jelly", "grape jelly shorthand" ],
      [ /\bSTRW JAM\b/i, "Strawberry Jam", "strawberry jam shorthand" ],
      [ /\b(JELLY|JAM)\b/i, "Jelly and Jam", "jelly/jam shorthand; type not visible" ],
      [ /\bMARMLD\b/i, "Marmalade", "marmalade shorthand" ],
      [ /\bPC SYRUP\b/i, "Syrup Packets", "syrup packet shorthand" ],
      [ /\bSYRUP LOG CABIN\b/i, "Log Cabin Syrup", "Log Cabin syrup shorthand" ],
      [ /\bSYRUP\b/i, "Syrup", "syrup shorthand; format not visible" ],
      [ /\bOIL CANOLA\b/i, "Canola Oil", "canola oil shorthand" ],
      [ /\bOIL CLEAR FRY\b/i, "Clear Frying Oil", "clear frying oil shorthand" ],
      [ /\bOIL\b/i, "Oil", "oil shorthand; type not visible" ],
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
      [ /\bPROD ONION VD\/SWT\b/i, "Sweet Onions", "sweet onion shorthand" ],
      [ /\bPROD ONION YELLOW\b/i, "Yellow Onions", "yellow onion shorthand" ],
      [ /\bPROD ONION\b/i, "Onions", "onion produce shorthand; variety not visible" ],
      [ /\bPROD PARS\b/i, "Parsley", "parsley produce shorthand" ],
      [ /\bPROD POTATO\b/i, "Potatoes", "potato produce shorthand" ],
      [ /\bFZ SPINACH\b/i, "Frozen Spinach", "frozen spinach shorthand" ],
      [ /\bPROD SPINACH\b/i, "Fresh Spinach", "fresh spinach shorthand" ],
      [ /\b(PROD SPINACH|FZ SPINACH)\b/i, "Spinach", "spinach shorthand; format not visible" ],
      [ /\bPROD TOFU\b/i, "Tofu", "tofu produce shorthand" ],
      [ /\bPROD TOMATO\b/i, "Tomatoes", "tomato produce shorthand" ],
      [ /\bMUSHROOM SLICED #10\b/i, "Canned Sliced Mushrooms", "canned sliced mushroom shorthand" ],
      [ /\bPD MUSH SLICED\b/i, "Fresh Sliced Mushrooms", "fresh sliced mushroom shorthand" ],
      [ /\b(PD MUSH|MUSHROOM)\b/i, "Mushrooms", "mushroom shorthand; format not visible" ],
      [ /\bBAG WHT 4LB\b/i, "White Paper Bags 4 lb", "4 lb white paper bag shorthand" ],
      [ /\bBAG WHT 8LB\b/i, "White Paper Bags 8 lb", "8 lb white paper bag shorthand" ],
      [ /\bBAG WHT 12LB\b/i, "White Paper Bags 12 lb", "12 lb white paper bag shorthand" ],
      [ /\bBAG WHT\b/i, "White Paper Bags", "white paper bag shorthand; size not visible" ],
      [ /\bBAG POLY BREAD\b/i, "Poly Bread Bags", "poly bread bag shorthand" ],
      [ /SMILEFACE/i, "Smile Face Bags", "smile face bag shorthand" ],
      [ /\bGLOVE NITRL\b.*\b M\b/i, "Nitrile Gloves Medium", "medium nitrile glove shorthand" ],
      [ /\bGLOVE NITRL\b.*\b L\b/i, "Nitrile Gloves Large", "large nitrile glove shorthand" ],
      [ /\bGLOVE NITRL\b/i, "Nitrile Gloves", "nitrile glove shorthand; size not visible" ],
      [ /\bGLOVE POW LATEX\b/i, "Latex Gloves", "latex glove shorthand" ],
      [ /\bAPRON BIB\b/i, "Bib Aprons", "bib apron shorthand" ],
      [ /\bAPRON WAIST\b/i, "Waist Aprons", "waist apron shorthand" ],
      [ /\bAPRON\b/i, "Aprons", "apron shorthand; style not visible" ],
      [ /\bCUP HOT\b.*\b12Z\b/i, "Hot Cups 12 oz", "12 oz hot cup shorthand" ],
      [ /\bCUP HOT\b.*\b16Z\b/i, "Hot Cups 16 oz", "16 oz hot cup shorthand" ],
      [ /\bHOT.*CUP|CUP HOT\b/i, "Hot Cups", "hot cup shorthand; size not visible" ],
      [ /\bCUP SAUCE\b.*\b2\.50Z\b/i, "Portion Cups 2.5 oz", "2.5 oz portion cup shorthand" ],
      [ /\bCUP SFL\b.*\b2Z\b/i, "Portion Cups 2 oz", "2 oz portion cup shorthand" ],
      [ /\bCUP SFL\b.*\b4Z\b/i, "Portion Cups 4 oz", "4 oz portion cup shorthand" ],
      [ /\bCUP SFL|CUP SAUCE\b/i, "Portion Cups", "portion cup shorthand; size not visible" ],
      [ /\bCUP FM\b/i, "Foam Cups", "foam cup shorthand" ],
      [ /\bLID.*SOUF 1Z|LID SFL 1Z\b/i, "Portion Cup Lids 1 oz", "1 oz portion lid shorthand" ],
      [ /\bLID SFL 1\.5-2Z\b/i, "Portion Cup Lids 1.5-2 oz", "1.5-2 oz portion lid shorthand" ],
      [ /\bLID.*SOUF|LID SFL\b/i, "Portion Cup Lids", "portion cup lid shorthand; size not visible" ],
      [ /\bCONT FM HNG\b.*\b8"1C\b/i, "Foam Hinged Containers 8 inch 1 compartment", "8 inch 1 compartment foam container shorthand" ],
      [ /\bCONT FM HNG\b.*\b8"3C\b/i, "Foam Hinged Containers 8 inch 3 compartment", "8 inch 3 compartment foam container shorthand" ],
      [ /\bCONT FM HNG\b/i, "Foam Hinged Containers", "foam hinged container shorthand; compartment count not visible" ],
      [ /\bLINER BK SKY4046XH\b/i, "Black Can Liners 40x46 XH", "black can liner 40x46 XH shorthand" ],
      [ /\bLINER BK SKY4046XX\b/i, "Black Can Liners 40x46 XX", "black can liner 40x46 XX shorthand" ],
      [ /\bLINER BK SL2424\b/i, "Black Can Liners 24x24", "black can liner 24x24 shorthand" ],
      [ /\bLINER CL SKY3339XH\b/i, "Clear Can Liners 33x39 XH", "clear can liner 33x39 XH shorthand" ],
      [ /\bLINER\b/i, "Liners", "liner shorthand; size not visible" ],
      [ /\bNAPKIN DINNER 2PLY\b/i, "Dinner Napkins 2-ply", "2-ply dinner napkin shorthand" ],
      [ /\bNAPKIN DINNER\b/i, "Dinner Napkins", "dinner napkin shorthand" ],
      [ /\bNAPKIN\b/i, "Napkins", "napkin shorthand; type not visible" ],
      [ /\bTOWEL ROLL\b/i, "Paper Towels", "paper towel roll shorthand" ],
      [ /\bMICROFBR TWL\b/i, "Microfiber Towels", "microfiber towel shorthand" ],
      [ /\bTOWEL TERRY STRIP\b/i, "Striped Terry Towels", "striped terry towel shorthand" ],
      [ /\bTOWEL TERRY|TERRY TOWEL\b/i, "Terry Towels", "terry towel shorthand" ],
      [ /\bWAX 8X10\.75\b/i, "Wax Paper 8x10.75", "8x10.75 wax paper shorthand" ],
      [ /\bWAX PPR 15X10\.75\b/i, "Wax Paper 15x10.75", "15x10.75 wax paper shorthand" ],
      [ /\bWAX\b/i, "Wax Paper", "wax paper shorthand; size not visible" ],
      [ /\bSTRW\b/i, "Straws", "straw shorthand" ],
      [ /\bLABEL\b/i, "Shelf Life Labels", "shelf life label shorthand" ],
      [ /\bCHECKS GR 240-50SW\b/i, "Guest Checks 240-50SW", "guest check 240-50SW shorthand" ],
      [ /\bCHECKS GR G7000SP\b/i, "Guest Checks G7000SP", "guest check G7000SP shorthand" ],
      [ /\bCHECKS\b/i, "Guest Checks", "guest check shorthand; type not visible" ],
      [ /\bDIAL COMPLETE\b/i, "Dial Complete Hand Soap", "Dial Complete soap shorthand" ],
      [ /\bDIAL FIT\b/i, "Dial FIT Hand Soap", "Dial FIT soap shorthand" ],
      [ /\bDIAL\b/i, "Hand Soap", "Dial soap shorthand; type not visible" ],
      [ /\b(PALMOLIVE|DISH)\b/i, "Dish Soap", "dish soap shorthand" ],
      [ /\bALL PURP DEGRSR\b/i, "All Purpose Degreaser", "all-purpose degreaser shorthand" ],
      [ /\bTOTAL DEGR\b/i, "Total Degreaser", "total degreaser shorthand" ],
      [ /\b(DEGR|DEGRSR)\b/i, "Degreaser", "degreaser shorthand; type not visible" ],
      [ /\bGRILL BRICK\b/i, "Grill Bricks", "grill brick shorthand" ],
      [ /\bSPONGE\b/i, "Sponges", "sponge shorthand" ],
      [ /\bSCRUBBER\b/i, "Scrubbers", "scrubber shorthand" ],
      [ /\bHAIRNET\b/i, "Hairnets", "raw name contains HAIRNET" ],
      [ /\bDOMINION DNR FORK\b/i, "Disposable Dinner Forks", "dinner fork shorthand" ],
      [ /\bDOMINION DNR KNIFE\b/i, "Disposable Dinner Knives", "dinner knife shorthand" ],
      [ /\bDOMINION DESSRT SP\b/i, "Disposable Dessert Spoons", "dessert spoon shorthand" ],
      [ /\bKIT FKSN\b/i, "Disposable Cutlery Kits", "cutlery kit shorthand" ],
      [ /\bCUTLERY BIN\b/i, "Cutlery Bins", "cutlery bin shorthand" ],
      [ /\bCUTLERY|DOMINION DNR FORK|DOMINION DNR KNIFE|DOMINION DESSRT SP|KIT FKSN\b/i, "Disposable Cutlery", "cutlery shorthand; type not visible" ],
      [ /\bBUS BOX 1\/2 LID\b/i, "Bus Box Lids", "bus box lid shorthand" ],
      [ /\bBUS BOX 1\/2 WHT\b/i, "White Bus Boxes", "white bus box shorthand" ],
      [ /\bBUS BOX BLACK\b/i, "Black Bus Boxes", "black bus box shorthand" ],
      [ /\bBUS BOX\b/i, "Bus Boxes", "bus box shorthand; style not visible" ],
      [ /\bKLEEN PAIL\b.*\bGRN\b/i, "Green Cleaning Pails", "green cleaning pail shorthand" ],
      [ /\bKLEEN PAIL\b.*\bRED\b/i, "Red Cleaning Pails", "red cleaning pail shorthand" ],
      [ /\bKLEEN PAIL\b/i, "Cleaning Pails", "cleaning pail shorthand; color not visible" ],
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
