const strings = @import("strings.zig");

pub fn waterTemplates(
    locale: strings.Locale,
) []const []const u8 {
    return switch (locale) {
        .en => &en_water,
        .pl => &pl_water,
    };
}

pub fn proteinTemplates(
    locale: strings.Locale,
) []const []const u8 {
    return switch (locale) {
        .en => &en_protein,
        .pl => &pl_protein,
    };
}

pub fn concreteTemplates(
    locale: strings.Locale,
) []const []const u8 {
    return switch (locale) {
        .en => &en_concrete,
        .pl => &pl_concrete,
    };
}

comptime {
    if (en_water.len != pl_water.len)
        @compileError("water template count mismatch");
    if (en_protein.len != pl_protein.len)
        @compileError("protein template count mismatch");
    if (en_concrete.len != pl_concrete.len)
        @compileError("concrete template count mismatch");
}

// ---- English water templates ----
// Variables: {time}, {water_drank}, {water_left}

const en_water = [_][]const u8{
    "\xF0\x9F\x92\xA7 It's {time} and you've"
        ++ " only logged {water_drank} ml."
        ++ " Uric acid won't flush itself."
        ++ " Hit that thermos!",
    "\xF0\x9F\x92\xA7 Clock's ticking ({time}),"
        ++ " and your kidneys are asking"
        ++ " for backup. Still {water_left} ml"
        ++ " short of keeping your joints"
        ++ " safe today.",
    "\xF0\x9F\x92\xA7 Hydration status:"
        ++ " warning ({water_drank} ml)."
        ++ " Brew some rooibos, or your"
        ++ " fingers will remind you"
        ++ " tomorrow morning.",
    "\xF0\x9F\x92\xA7 Dude, {water_drank} ml"
        ++ " at {time}? With your protein"
        ++ " intake that's like fighting"
        ++ " a fire with a thimble. Drink!",
    "\xF0\x9F\x92\xA7 Purine alert!"
        ++ " Kidding, but if you don't hit"
        ++ " those missing {water_left} ml,"
        ++ " it'll stop being a joke."
        ++ " Chug water.",
    "\xF0\x9F\x92\xA7 Mounjaro kills your thirst,"
        ++ " and you've only logged"
        ++ " {water_drank} ml."
        ++ " Do your kidneys a favor"
        ++ " and empty a glass.",
    "\xF0\x9F\x92\xA7 Time for a pit stop."
        ++ " You're {water_left} ml short"
        ++ " of your goal."
        ++ " Pour yourself some fluids.",
    "\xF0\x9F\x92\xA7 Charts show a drought."
        ++ " {water_drank} ml at {time}"
        ++ " is asking for joint trouble."
        ++ " Tank up!",
    "\xF0\x9F\x92\xA7 Your blood is about to turn"
        ++ " into jelly. You still have"
        ++ " {water_left} ml to drink before"
        ++ " bed. Start now.",
    "\xF0\x9F\x92\xA7 Kidneys report error 404"
        ++ " \xE2\x80\x94 Water Not Found."
        ++ " Counter shows a pitiful"
        ++ " {water_drank} ml. Fix it.",
    "\xF0\x9F\x92\xA7 Tirzepatide killed your"
        ++ " thirst signal, so MetOS steps"
        ++ " in. {water_left} ml short. Drink.",
    "\xF0\x9F\x92\xA7 Thermos pump is waiting."
        ++ " You need exactly"
        ++ " {water_left} ml to reach"
        ++ " the safe zone for your feet.",
    "\xF0\x9F\x92\xA7 It's {time}."
        ++ " If you don't start catching"
        ++ " up on those {water_left} ml,"
        ++ " you'll be chugging a bucket"
        ++ " before bed.",
    "\xF0\x9F\x92\xA7 Gout lurks where there's"
        ++ " no solvent. You've only logged"
        ++ " {water_drank} ml."
        ++ " Change that right now.",
    "\xF0\x9F\x92\xA7 Crystallization warning"
        ++ " system: ACTIVE."
        ++ " Remaining to pump:"
        ++ " {water_left} ml. Execute.",
};

// ---- English protein templates ----
// Variables: {missing_protein}, {flavor}

const en_protein = [_][]const u8{
    "\xF0\x9F\xA5\xA4 Day's ending and your"
        ++ " protein bar is empty."
        ++ " Missing {missing_protein}g."
        ++ " Blend an isolate shake,"
        ++ " add sucralose and {flavor}.",
    "\xF0\x9F\xA5\xA4 Catabolic alarm!"
        ++ " You're {missing_protein}g short"
        ++ " of your protein target."
        ++ " Fire up the blender with"
        ++ " {flavor} flavor.",
    "\xF0\x9F\xA5\xA4 Can't build a physique on"
        ++ " these gaps. Toss isolate in"
        ++ " the shaker, make it {flavor},"
        ++ " and nail those"
        ++ " {missing_protein}g.",
    "\xF0\x9F\xA5\xA4 Still {missing_protein}g"
        ++ " of protein to close the day."
        ++ " Time for the rescue potion:"
        ++ " WPI + water + {flavor}."
        ++ " Drink and grow.",
    "\xF0\x9F\xA5\xA4 Protein bar is crying."
        ++ " Mix a quick {flavor} shake"
        ++ " to patch that"
        ++ " {missing_protein}g hole"
        ++ " without touching purines.",
    "\xF0\x9F\xA5\xA4 System detected"
        ++ " building-block deficit"
        ++ " ({missing_protein}g)."
        ++ " Recommendation: lean protein"
        ++ " shake, {flavor} flavor."
        ++ " Zero carbs, full recovery.",
    "\xF0\x9F\xA5\xA4 Muscles won't maintain"
        ++ " themselves on a cut."
        ++ " You need {missing_protein}g more."
        ++ " Blend isolate ({flavor})"
        ++ " and sleep with a clear"
        ++ " conscience.",
    "\xF0\x9F\xA5\xA4 Warning: protein intake"
        ++ " too low. Rescue your macros"
        ++ " with a {flavor} shake to"
        ++ " painlessly cover those"
        ++ " missing {missing_protein}g.",
    "\xF0\x9F\xA5\xA4 Low on calories but still"
        ++ " short {missing_protein}g of"
        ++ " protein. Isolate with a hint"
        ++ " of {flavor} will solve this"
        ++ " engineering problem in"
        ++ " a minute.",
    "\xF0\x9F\xA5\xA4 Closing the day? Not yet."
        ++ " Still {missing_protein}g of"
        ++ " protein to go. Flavor your"
        ++ " water with {flavor},"
        ++ " add pure WPI, drink up.",
    "\xF0\x9F\xA5\xA4 Mission right now:"
        ++ " eliminate the"
        ++ " {missing_protein}g protein"
        ++ " deficit. Suggested payload:"
        ++ " isolate + {flavor} aroma.",
    "\xF0\x9F\xA5\xA4 Won't let you burn"
        ++ " hard-earned tissue."
        ++ " Blend a rescue shake"
        ++ " ({flavor}) to add those"
        ++ " missing {missing_protein}g"
        ++ " before bed.",
    "\xF0\x9F\xA5\xA4 Stockroom shortage."
        ++ " Deliver {missing_protein}g"
        ++ " of protein immediately."
        ++ " Today's recommended WPI"
        ++ " flavor: {flavor}.",
    "\xF0\x9F\xA5\xA4 Macro rescue activated!"
        ++ " {missing_protein}g to target."
        ++ " Liquid isolate and a few"
        ++ " drops of {flavor} will"
        ++ " get it done.",
    "\xF0\x9F\xA5\xA4 Want to close the day"
        ++ " green in the app? Drink the"
        ++ " missing {missing_protein}g of"
        ++ " protein. Today I suggest"
        ++ " {flavor} flavor.",
};

// ---- English concrete templates ----
// Variables: {fiber}, {water}

const en_concrete = [_][]const u8{
    "\xF0\x9F\xA7\xB1 You ate {fiber}g of fiber"
        ++ " today, and water sits at"
        ++ " {water} ml. On Mounjaro"
        ++ " that's cement in your gut."
        ++ " Tank up immediately!",
    "\xF0\x9F\xA7\xB1 Gastric alert! Fiber"
        ++ " ({fiber}g) to water"
        ++ " ({water} ml) ratio is tragic."
        ++ " Down two big glasses"
        ++ " before it dries out.",
    "\xF0\x9F\xA7\xB1 Your gut is screaming for"
        ++ " help. {fiber}g of fiber"
        ++ " without hydration"
        ++ " ({water} ml on the counter)"
        ++ " is begging for a massive"
        ++ " blockage. Drink!",
    "\xF0\x9F\xA7\xB1 Whole grain and beans are"
        ++ " doing their job, but you ate"
        ++ " {fiber}g of fiber with only"
        ++ " {water} ml of fluids."
        ++ " Wash it down before it"
        ++ " stops moving.",
    "\xF0\x9F\xA7\xB1 Concrete index is flashing"
        ++ " red. You pushed {fiber}g"
        ++ " of broom with only"
        ++ " {water} ml of lubricant."
        ++ " Top up water.",
    "\xF0\x9F\xA7\xB1 Watch out for constipation."
        ++ " Mounjaro slows digestion,"
        ++ " and with {fiber}g of fiber"
        ++ " and {water} ml of water,"
        ++ " disaster is close."
        ++ " Fire up the thermos.",
    "\xF0\x9F\xA7\xB1 Dangerous concentration of"
        ++ " fiber ({fiber}g) at"
        ++ " critically low hydration"
        ++ " ({water} ml). Dilute it"
        ++ " before it's too late.",
    "\xF0\x9F\xA7\xB1 Fiber ({fiber}g) needs"
        ++ " water like a sponge."
        ++ " You gave it barely"
        ++ " {water} ml. Pump fluids"
        ++ " or tomorrow will hurt.",
    "\xF0\x9F\xA7\xB1 You packed in {fiber}g"
        ++ " of fiber. Great, but at"
        ++ " {water} ml of water"
        ++ " that's not a broom,"
        ++ " it's a cork."
        ++ " Drink at least 500ml.",
    "\xF0\x9F\xA7\xB1 Gut status: concrete"
        ++ " threat. You loaded {fiber}g"
        ++ " of fiber, washed down"
        ++ " with merely {water} ml"
        ++ " of fluid. React!",
    "\xF0\x9F\xA7\xB1 Mounjaro + {fiber}g fiber"
        ++ " + only {water} ml water"
        ++ " = hardware failure in the"
        ++ " bathroom. Fix this algorithm"
        ++ " bug with a liter of rooibos.",
    "\xF0\x9F\xA7\xB1 Anti-constipation system"
        ++ " activated. Too big a gap"
        ++ " between dry fiber ({fiber}g)"
        ++ " and water ({water} ml)."
        ++ " Let's drink.",
    "\xF0\x9F\xA7\xB1 Good fiber score ({fiber}g),"
        ++ " tragic water score"
        ++ " ({water} ml)."
        ++ " Wash down those carbs so"
        ++ " they can safely exit"
        ++ " the system.",
    "\xF0\x9F\xA7\xB1 Blockage warning. Balance"
        ++ " of {fiber}g fiber to"
        ++ " {water} ml is simply"
        ++ " an engineering flaw."
        ++ " Pour water into yourself.",
    "\xF0\x9F\xA7\xB1 Fiber loves water, and"
        ++ " your system is in a drought"
        ++ " ({water} ml). Take emergency"
        ++ " fluids so those {fiber}g can"
        ++ " work for your cut.",
};

// ---- Polish water templates ----

const pl_water = [_][]const u8{
    "\xF0\x9F\x92\xA7 Mamy {time}, a u Ciebie"
        ++ " na liczniku ledwo {water_drank} ml."
        ++ " Kwas moczowy sam si\xC4\x99 nie"
        ++ " wyp\xC5\x82ucze. Pompuj z termosu!",
    "\xF0\x9F\x92\xA7 Zegar tyka ({time}),"
        ++ " a nerki prosz\xC4\x85 o wsparcie."
        ++ " Brakuje jeszcze {water_left} ml,"
        ++ " \xC5\xBCeby stawy by\xC5\x82y"
        ++ " dzisiaj w 100% bezpieczne.",
    "\xF0\x9F\x92\xA7 Status nawodnienia:"
        ++ " ostrzegawczy ({water_drank} ml)."
        ++ " Zalej Rooibosa, bo jutro rano"
        ++ " poczujesz to w palcach.",
    "\xF0\x9F\x92\xA7 Stary, {water_drank} ml"
        ++ " o {time}? Przy Twojej poda\xC5\xBCy"
        ++ " bia\xC5\x82ka to jak gaszenie"
        ++ " po\xC5\xBCaru naparstkiem. Pijemy!",
    "\xF0\x9F\x92\xA7 Alert purynowy!"
        ++ " \xC5\xBBartuj\xC4\x99, ale"
        ++ " je\xC5\x9Bli nie dobijesz"
        ++ " brakuj\xC4\x85cych {water_left} ml,"
        ++ " to przestanie by\xC4\x87"
        ++ " \xC5\xBCartem."
        ++ " \xC5\x81ykaj wod\xC4\x99.",
    "\xF0\x9F\x92\xA7 Mounjaro bezlito\xC5\x9Bnie"
        ++ " wysusza, a Ty masz zalogowane"
        ++ " tylko {water_drank} ml."
        ++ " Zr\xC3\xB3b przys\xC5\x82ug\xC4\x99"
        ++ " swoim nerkom i opr\xC3\xB3\xC5\xBCnij"
        ++ " szklank\xC4\x99.",
    "\xF0\x9F\x92\xA7 Czas na pit-stop."
        ++ " Brakuje Ci {water_left} ml do celu."
        ++ " Zalej now\xC4\x85"
        ++ " porcj\xC4\x99 p\xC5\x82yn\xC3\xB3w.",
    "\xF0\x9F\x92\xA7 Widz\xC4\x99 na wykresach"
        ++ " susz\xC4\x99. {water_drank} ml"
        ++ " o {time} to proszenie si\xC4\x99"
        ++ " o k\xC5\x82opoty ze stawami. Tankuj!",
    "\xF0\x9F\x92\xA7 Twoja krew zaraz zamieni"
        ++ " si\xC4\x99 w kisiel. Masz jeszcze"
        ++ " {water_left} ml do wypicia przed"
        ++ " noc\xC4\x85. Zaczynamy od teraz.",
    "\xF0\x9F\x92\xA7 Nerki zg\xC5\x82aszaj\xC4\x85"
        ++ " b\xC5\x82\xC4\x85" ++ "d 404 -"
        ++ " Water Not Found. Na liczniku wisi"
        ++ " \xC5\xBC" ++ "a\xC5\x82osne"
        ++ " {water_drank} ml. Napraw to.",
    "\xF0\x9F\x92\xA7 Tirzepatyd odci\xC4\x85\xC5\x82"
        ++ " Ci pragnienie, wi\xC4\x99c MetOS"
        ++ " musi interweniowa\xC4\x87."
        ++ " Brakuje {water_left} ml. Pij.",
    "\xF0\x9F\x92\xA7 Pompka z termosu czeka."
        ++ " Zosta\xC5\x82o Ci dok\xC5\x82adnie"
        ++ " {water_left} ml do bezpiecznej"
        ++ " strefy dla Twoich st\xC3\xB3p.",
    "\xF0\x9F\x92\xA7 Wybi\xC5\x82a {time}."
        ++ " Je\xC5\x9Bli teraz nie zaczniesz"
        ++ " nadrabia\xC4\x87 tych"
        ++ " {water_left} ml, przed snem"
        ++ " b\xC4\x99dziesz musia\xC5\x82"
        ++ " wypi\xC4\x87 wiadro.",
    "\xF0\x9F\x92\xA7 Podagra czai si\xC4\x99 tam,"
        ++ " gdzie brakuje rozpuszczalnika."
        ++ " Masz na koncie dopiero"
        ++ " {water_drank} ml."
        ++ " Zmie\xC5\x84 to natychmiast.",
    "\xF0\x9F\x92\xA7 System ostrzegania przed"
        ++ " krystalizacj\xC4\x85:"
        ++ " W\xC5\x82\xC4\x85czony."
        ++ " Zosta\xC5\x82o do przepompowania:"
        ++ " {water_left} ml. Wykonaj.",
};

// ---- Polish protein templates ----

const pl_protein = [_][]const u8{
    "\xF0\x9F\xA5\xA4 Dzie\xC5\x84 si\xC4\x99"
        ++ " ko\xC5\x84czy, a pasek bia\xC5\x82ka"
        ++ " \xC5\x9Bwieci pustkami."
        ++ " Brakuje {missing_protein}g."
        ++ " Kr\xC4\x99\xC4\x87 szejka z izolatu,"
        ++ " dodaj sukraloz\xC4\x99"
        ++ " i aromat {flavor}.",
    "\xF0\x9F\xA5\xA4 Alarm kataboliczny!"
        ++ " Do celu brakuje Ci"
        ++ " {missing_protein}g bia\xC5\x82ka."
        ++ " Odpalaj blender i zapraw"
        ++ " to aromatem {flavor}.",
    "\xF0\x9F\xA5\xA4 Nie zrobimy formy na"
        ++ " takich brakach. Wrzucaj izolat"
        ++ " do szejkera, podkr\xC4\x99\xC4\x87"
        ++ " go na {flavor} i dobij te"
        ++ " {missing_protein}g.",
    "\xF0\x9F\xA5\xA4 Zosta\xC5\x82o"
        ++ " {missing_protein}g bia\xC5\x82ka"
        ++ " do zamkni\xC4\x99cia dnia."
        ++ " Czas na eliksir ratunkowy:"
        ++ " WPI + woda + {flavor}."
        ++ " Pij i ro\xC5\x9Bnij.",
    "\xF0\x9F\xA5\xA4 Pasek bia\xC5\x82ka"
        ++ " p\xC5\x82acze. Zr\xC3\xB3b"
        ++ " szybkiego szejka z aromatem"
        ++ " {flavor}, \xC5\xBCeby"
        ++ " za\xC5\x82ata\xC4\x87 te"
        ++ " {missing_protein}g dziury"
        ++ " bez ruszania puryn.",
    "\xF0\x9F\xA5\xA4 System wykry\xC5\x82"
        ++ " deficyt budulca"
        ++ " ({missing_protein}g)."
        ++ " Rekomendacja: chudy szejk"
        ++ " bia\xC5\x82kowy o smaku {flavor}."
        ++ " Zero w\xC4\x99gli,"
        ++ " pe\xC5\x82na regeneracja.",
    "\xF0\x9F\xA5\xA4 Mi\xC4\x99\xC5\x9Bnie"
        ++ " same si\xC4\x99 nie utrzymaj\xC4\x85"
        ++ " na redukcji. Masz"
        ++ " {missing_protein}g do nadrobienia."
        ++ " Zmiksuj izolat ({flavor})"
        ++ " i k\xC5\x82" ++ "ad\xC5\xBA"
        ++ " si\xC4\x99 spa\xC4\x87 z czystym"
        ++ " sumieniem.",
    "\xF0\x9F\xA5\xA4 Ostrze\xC5\xBCenie:"
        ++ " Za niska poda\xC5\xBC bia\xC5\x82ka."
        ++ " Ratuj makro szejkiem o smaku"
        ++ " {flavor}, \xC5\xBCeby bezbole\xC5\x9Bnie"
        ++ " dobi\xC4\x87 brakuj\xC4\x85ce"
        ++ " {missing_protein}g.",
    "\xF0\x9F\xA5\xA4 Masz ma\xC5\x82o kalorii,"
        ++ " ale wci\xC4\x85\xC5\xBC brakuje"
        ++ " {missing_protein}g bia\xC5\x82ka."
        ++ " Izolat z nut\xC4\x85 {flavor}"
        ++ " rozwi\xC4\x85\xC5\xBCe ten"
        ++ " in\xC5\xBCynieryjny problem"
        ++ " w minut\xC4\x99.",
    "\xF0\x9F\xA5\xA4 Zamykamy dzie\xC5\x84?"
        ++ " Jeszcze nie. Zosta\xC5\x82o"
        ++ " {missing_protein}g bia\xC5\x82ka."
        ++ " Aromatyzuj wod\xC4\x99 smakiem"
        ++ " {flavor}, dodaj czyste WPI"
        ++ " i wypij do dna.",
    "\xF0\x9F\xA5\xA4 Misja na teraz:"
        ++ " zlikwidowa\xC4\x87 deficyt"
        ++ " {missing_protein}g bia\xC5\x82ka."
        ++ " Sugerowany \xC5\x82adunek:"
        ++ " izolat + aromat {flavor}.",
    "\xF0\x9F\xA5\xA4 Nie pozwolimy spali\xC4\x87"
        ++ " ci\xC4\x99\xC5\xBCko wypracowanej"
        ++ " tkanki. Kr\xC4\x99\xC4\x87 szejka"
        ++ " ratunkowego ({flavor}),"
        ++ " \xC5\xBCeby do\xC5\x82o\xC5\xBCy\xC4\x87"
        ++ " te brakuj\xC4\x85ce"
        ++ " {missing_protein}g na noc.",
    "\xF0\x9F\xA5\xA4 Braki na magazynie"
        ++ " budowlanym. Dostarcz natychmiast"
        ++ " {missing_protein}g bia\xC5\x82ka."
        ++ " Dzisiejszy polecany smak"
        ++ " do WPI to {flavor}.",
    "\xF0\x9F\xA5\xA4 Makro ratunek aktywowany!"
        ++ " Zosta\xC5\x82o {missing_protein}g"
        ++ " do celu. P\xC5\x82ynny izolat"
        ++ " i kilka kropel {flavor}"
        ++ " za\xC5\x82atwi\xC4\x85"
        ++ " spraw\xC4\x99.",
    "\xF0\x9F\xA5\xA4 Chcesz zamkn\xC4\x85\xC4\x87"
        ++ " dzie\xC5\x84 w apce na zielono?"
        ++ " Wypij brakuj\xC4\x85ce"
        ++ " {missing_protein}g bia\xC5\x82ka."
        ++ " Dzi\xC5\x9B proponuj\xC4\x99"
        ++ " wersj\xC4\x99 z aromatem {flavor}.",
};

// ---- Polish concrete templates ----

const pl_concrete = [_][]const u8{
    "\xF0\x9F\xA7\xB1 Zjad\xC5\x82e\xC5\x9B"
        ++ " dzisiaj {fiber}g b\xC5\x82onnika,"
        ++ " a woda stoi na {water} ml."
        ++ " Przy Mounjaro to gotowy beton"
        ++ " w jelitach. Tankuj natychmiast!",
    "\xF0\x9F\xA7\xB1 Alert gastryczny!"
        ++ " Stosunek b\xC5\x82onnika ({fiber}g)"
        ++ " do wody ({water} ml) jest tragiczny."
        ++ " Wypij od razu dwie du\xC5\xBCe"
        ++ " szklanki, zanim to zaschnie.",
    "\xF0\x9F\xA7\xB1 Twoje jelita krzycz\xC4\x85"
        ++ " o pomoc. {fiber}g b\xC5\x82onnika"
        ++ " bez popicia ({water} ml na"
        ++ " liczniku) to proszenie si\xC4\x99"
        ++ " o pot\xC4\x99\xC5\xBCny korek. Pij!",
    "\xF0\x9F\xA7\xB1 Razowiec i fasola robi\xC4\x85"
        ++ " robot\xC4\x99, ale zjad\xC5\x82e\xC5\x9B"
        ++ " {fiber}g b\xC5\x82onnika przy zaledwie"
        ++ " {water} ml p\xC5\x82yn\xC3\xB3w."
        ++ " Zalej to wod\xC4\x85, zanim stanie"
        ++ " w miejscu.",
    "\xF0\x9F\xA7\xB1 Wska\xC5\xBAnik betonu"
        ++ " \xC5\x9Bwieci na czerwono."
        ++ " Wcisn\xC4\x85\xC5\x82e\xC5\x9B"
        ++ " {fiber}g miot\xC5\x82y, a masz"
        ++ " tylko {water} ml p\xC5\x82ynu"
        ++ " do po\xC5\x9Blizgu."
        ++ " Uzupe\xC5\x82nij wod\xC4\x99.",
    "\xF0\x9F\xA7\xB1 Uwaga na zaparcia."
        ++ " Mounjaro spowalnia trawienie,"
        ++ " a przy {fiber}g b\xC5\x82onnika"
        ++ " i {water} ml wody katastrofa"
        ++ " jest blisko. Uruchom termos.",
    "\xF0\x9F\xA7\xB1 Zanotowano niebezpieczne"
        ++ " st\xC4\x99\xC5\xBCenie b\xC5\x82onnika"
        ++ " ({fiber}g) przy krytycznie niskim"
        ++ " nawodnieniu ({water} ml)."
        ++ " Rozcie\xC5\x84cz to, zanim"
        ++ " b\xC4\x99dzie za p\xC3\xB3\xC5\xBAno.",
    "\xF0\x9F\xA7\xB1 B\xC5\x82onnik ({fiber}g)"
        ++ " potrzebuje wody jak g\xC4\x85bka."
        ++ " Ty da\xC5\x82e\xC5\x9B mu ledwo"
        ++ " {water} ml. Pompuj p\xC5\x82yny,"
        ++ " bo jutro b\xC4\x99dzie bola\xC5\x82o.",
    "\xF0\x9F\xA7\xB1 Wci\xC4\x85gn\xC4\x85\xC5\x82"
        ++ "e\xC5\x9B {fiber}g b\xC5\x82onnika."
        ++ " Super, ale przy {water} ml wody"
        ++ " to nie miot\xC5\x82a, to korek"
        ++ " budowlany. Wypij min. 500ml.",
    "\xF0\x9F\xA7\xB1 Status jelit:"
        ++ " Zagro\xC5\xBCenie betonem."
        ++ " Masz za\xC5\x82adowane {fiber}g"
        ++ " b\xC5\x82onnika, a popite zaledwie"
        ++ " {water} ml p\xC5\x82ynu. Reaguj!",
    "\xF0\x9F\xA7\xB1 Mounjaro + {fiber}g"
        ++ " b\xC5\x82onnika + zaledwie {water} ml"
        ++ " wody = hardware failure w toalecie."
        ++ " Napraw ten b\xC5\x82\xC4\x85" ++ "d"
        ++ " algorytmu litrem Rooibosa.",
    "\xF0\x9F\xA7\xB1 System"
        ++ " przeciwzaparciowy aktywowany."
        ++ " Zbyt du\xC5\xBCa r\xC3\xB3\xC5\xBCnica"
        ++ " mi\xC4\x99dzy suchym b\xC5\x82onnikiem"
        ++ " ({fiber}g) a wod\xC4\x85"
        ++ " ({water} ml). Pijemy.",
    "\xF0\x9F\xA7\xB1 Dobry wynik b\xC5\x82onnika"
        ++ " ({fiber}g), tragiczny wynik wody"
        ++ " ({water} ml). Zalej te"
        ++ " w\xC4\x99glowodany,"
        ++ " \xC5\xBCeby mog\xC5\x82y bezpiecznie"
        ++ " opu\xC5\x9Bci\xC4\x87 system.",
    "\xF0\x9F\xA7\xB1 Ostrze\xC5\xBCenie"
        ++ " przed zatorem. Bilans {fiber}g"
        ++ " b\xC5\x82onnika do {water} ml to"
        ++ " po prostu in\xC5\xBCynieryjny"
        ++ " b\xC5\x82\xC4\x85" ++ "d uk\xC5\x82adu."
        ++ " Wlej w siebie wod\xC4\x99.",
    "\xF0\x9F\xA7\xB1 B\xC5\x82onnik kocha"
        ++ " wod\xC4\x99, a u Ciebie w"
        ++ " uk\xC5\x82adzie susza ({water} ml)."
        ++ " Przyjmij p\xC5\x82yny ratunkowe,"
        ++ " \xC5\xBCeby te {fiber}g mog\xC5\x82y"
        ++ " popracowa\xC4\x87 na redukcji.",
};
