const std = @import("std");
const database = @import("db.zig");
const kinetics = @import("kinetics.zig");

// --- Template variable replacement ---

const Var = struct { name: []const u8, value: []const u8 };

fn replaceTemplate(
    tmpl: []const u8,
    vars: []const Var,
    buf: []u8,
) ?[]const u8 {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < tmpl.len) {
        if (tmpl[i] == '{') {
            var matched = false;
            for (vars) |v| {
                const end = i + 1 + v.name.len;
                if (end < tmpl.len and
                    tmpl[end] == '}' and
                    std.mem.eql(
                    u8,
                    tmpl[i + 1 .. end],
                    v.name,
                ))
                {
                    if (pos + v.value.len > buf.len)
                        return null;
                    @memcpy(
                        buf[pos .. pos + v.value.len],
                        v.value,
                    );
                    pos += v.value.len;
                    i = end + 1;
                    matched = true;
                    break;
                }
            }
            if (matched) continue;
        }
        if (pos >= buf.len) return null;
        buf[pos] = tmpl[i];
        pos += 1;
        i += 1;
    }
    return buf[0..pos];
}

// --- Message template pools ---
// Variables: {time}, {water_drank}, {water_left}

const water_templates = [_][]const u8{
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

// Variables: {missing_protein}, {flavor}

const protein_templates = [_][]const u8{
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

// Variables: {fiber}, {water}

const concrete_templates = [_][]const u8{
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

const shake_flavors = [_][]const u8{
    "Kaktus",
    "Yummy Classic Rhubarb",
    "Jackfruit",
    "Milky Way",
};

// --- Check functions ---

pub fn checkWaterReminder(
    db: database.Db,
    date: []const u8,
    hour: u8,
    buf: []u8,
) ?[]const u8 {
    if (hour < 10 or hour > 21) return null;
    const key: []const u8 = if (hour < 15)
        "water_am"
    else
        "water_pm";
    if (db.isAlertSentToday(key, date) catch false)
        return null;

    const drunk = db.getDailyWater(date) catch
        return null;
    const threshold: i64 = if (hour < 15) 1000 else 1500;
    if (drunk >= threshold) return null;

    const goal = db.getGoal() catch null;
    const base: i64 = if (goal) |g|
        g.target_water_ml orelse 3000
    else
        3000;
    const left = @max(base - drunk, 0);

    db.markAlertSent(key, date) catch {};
    const idx = db.pickMsgIndex("water", 15) catch
        return null;
    if (idx >= water_templates.len) return null;

    var hour_buf: [8]u8 = undefined;
    const hour_str = std.fmt.bufPrint(
        &hour_buf,
        "{d}:00",
        .{hour},
    ) catch return null;
    var drunk_buf: [16]u8 = undefined;
    const drunk_str = std.fmt.bufPrint(
        &drunk_buf,
        "{d}",
        .{drunk},
    ) catch return null;
    var left_buf: [16]u8 = undefined;
    const left_str = std.fmt.bufPrint(
        &left_buf,
        "{d}",
        .{left},
    ) catch return null;

    return replaceTemplate(
        water_templates[idx],
        &[_]Var{
            .{ .name = "time", .value = hour_str },
            .{
                .name = "water_drank",
                .value = drunk_str,
            },
            .{
                .name = "water_left",
                .value = left_str,
            },
        },
        buf,
    );
}

pub fn checkProteinDeficit(
    db: database.Db,
    date: []const u8,
    hour: u8,
    buf: []u8,
) ?[]const u8 {
    if (hour < 20 or hour > 22) return null;
    if (db.isAlertSentToday(
        "protein_deficit",
        date,
    ) catch false)
        return null;

    const goal = (db.getGoal() catch return null)
        orelse return null;
    const target = goal.target_protein_g orelse
        return null;
    const current = db.getDailyProteinTotal(date) catch
        return null;
    const missing = target - current;
    if (missing < 30) return null;

    db.markAlertSent("protein_deficit", date) catch {};
    const idx = db.pickMsgIndex("protein", 15) catch
        return null;
    if (idx >= protein_templates.len) return null;

    const day = std.fmt.parseInt(
        usize,
        date[8..10],
        10,
    ) catch 1;
    const flavor = shake_flavors[
        (idx + day) % shake_flavors.len
    ];

    var miss_buf: [16]u8 = undefined;
    const miss_str = std.fmt.bufPrint(
        &miss_buf,
        "{d:.0}",
        .{missing},
    ) catch return null;

    return replaceTemplate(
        protein_templates[idx],
        &[_]Var{
            .{
                .name = "missing_protein",
                .value = miss_str,
            },
            .{ .name = "flavor", .value = flavor },
        },
        buf,
    );
}

pub fn checkConcreteIndex(
    db: database.Db,
    date: []const u8,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday("concrete", date) catch false)
        return null;

    const fiber = db.getDailyFiberTotal(date) catch
        return null;
    if (fiber < 30) return null;

    const water = db.getDailyWater(date) catch
        return null;
    if (water >= 1500) return null;

    db.markAlertSent("concrete", date) catch {};
    const idx = db.pickMsgIndex("concrete", 15) catch
        return null;
    if (idx >= concrete_templates.len) return null;

    var fiber_buf: [16]u8 = undefined;
    const fiber_str = std.fmt.bufPrint(
        &fiber_buf,
        "{d:.0}",
        .{fiber},
    ) catch return null;
    var water_buf: [16]u8 = undefined;
    const water_str = std.fmt.bufPrint(
        &water_buf,
        "{d}",
        .{water},
    ) catch return null;

    return replaceTemplate(
        concrete_templates[idx],
        &[_]Var{
            .{ .name = "fiber", .value = fiber_str },
            .{ .name = "water", .value = water_str },
        },
        buf,
    );
}

pub fn checkStomachLoad(
    db: database.Db,
    date: []const u8,
    hour: u8,
    calories: i64,
    fat: f64,
    buf: []u8,
) ?[]const u8 {
    if (hour < 20) return null;
    if (calories < 500 and fat < 20) return null;
    if (db.isAlertSentToday(
        "stomach_load",
        date,
    ) catch false) return null;

    db.markAlertSent("stomach_load", date) catch {};
    return std.fmt.bufPrint(
        buf,
        "\xE2\x9A\xA0\xEF\xB8\x8F Ci\xC4\x99\xC5\xBCki"
            ++ " posi\xC5\x82ek po 20:00!"
            ++ "\n{d} kcal, {d:.0}g"
            ++ " t\xC5\x82uszczu."
            ++ " Mounjaro spowalnia"
            ++ " opr\xC3\xB3\xC5\xBCnianie"
            ++ " \xC5\xBCo\xC5\x82\xC4\x85" ++ "dka"
            ++ " \xE2\x80\x94 ryzyko refluksu!",
        .{ calories, fat },
    ) catch null;
}

pub fn checkPurine72h(
    db: database.Db,
    date: []const u8,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday(
        "purine_72h",
        date,
    ) catch false) return null;

    const high_days = db.countHighPurineDays(date) catch
        return null;
    if (high_days < 2) return null;

    db.markAlertSent("purine_72h", date) catch {};
    return std.fmt.bufPrint(
        buf,
        "\xF0\x9F\x92\x80 Bufor purynowy 72h"
            ++ " przekroczony!"
            ++ "\n{d} z 3 dni z wysokimi purynami."
            ++ "\nDzi\xC5\x9B tylko"
            ++ " nabia\xC5\x82/WPI \xE2\x80\x94"
            ++ " zero mi\xC4\x99sa!"
            ++ "\nKwas moczowy kumuluje"
            ++ " si\xC4\x99 \xE2\x80\x94"
            ++ " daj stawom oddech.",
        .{high_days},
    ) catch null;
}

pub fn checkAntiCatabolic(
    db: database.Db,
    date: []const u8,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday(
        "anti_catabolic",
        date,
    ) catch false) return null;

    const pct = (db.getWeeklyWeightChange(date) catch
        return null) orelse return null;
    if (pct > -1.5) return null;

    db.markAlertSent("anti_catabolic", date) catch {};
    return std.fmt.bufPrint(
        buf,
        "\xE2\x9A\xA0\xEF\xB8\x8F Zbyt szybki"
            ++ " spadek wagi!"
            ++ "\nTygodniowa zmiana: {d:.1}%"
            ++ "\nTak stromy spadek pali"
            ++ " mi\xC4\x99\xC5\x9Bnie,"
            ++ " nie t\xC5\x82uszcz."
            ++ "\nDodaj +150-200 kcal,"
            ++ " \xC5\xBCeby chroni\xC4\x87"
            ++ " tkank\xC4\x99 mi\xC4\x99\xC5\x9Bniow"
            ++ "\xC4\x85.",
        .{pct},
    ) catch null;
}

pub fn checkForceFeed(
    db: database.Db,
    date: []const u8,
    hour: u8,
    buf: []u8,
) ?[]const u8 {
    if (hour < 12 or hour > 20) return null;
    if (db.isAlertSentToday("force_feed", date) catch false)
        return null;

    const inj = db.getRecentInjections(
        date, hour,
    ) catch return null;
    if (inj.len == 0) return null;

    const suppression = kinetics.appetiteSuppression(
        inj.records[0].hours_ago,
    );
    if (suppression <= 0.8) return null;

    const goal = (db.getGoal() catch return null)
        orelse return null;
    const target = goal.target_protein_g orelse return null;
    const current = db.getDailyProteinTotal(date) catch
        return null;
    const hour_f: f64 = @floatFromInt(hour);
    if (current >= target * hour_f / 24.0) return null;

    db.markAlertSent("force_feed", date) catch {};
    return std.fmt.bufPrint(
        buf,
        "\xF0\x9F\xA5\xA4 Force Feed!"
            ++ " Szczyt t\xC5\x82umienia ({d:.0}%)."
            ++ "\nBrak g\xC5\x82odu nie znaczy,"
            ++ " \xC5\xBCe cia\xC5\x82o nie potrzebuje"
            ++ " budulca."
            ++ "\nWypij szejka WPI/Skyr!",
        .{suppression * 100},
    ) catch null;
}

pub fn checkPurineSentry(
    db: database.Db,
    date: []const u8,
    hour: u8,
    buf: []u8,
) ?[]const u8 {
    if (hour < 10 or hour > 20) return null;
    if (db.isAlertSentToday("purine_sentry", date) catch false)
        return null;

    const inj = db.getRecentInjections(
        date, hour,
    ) catch return null;
    if (inj.len == 0) return null;

    const suppression = kinetics.appetiteSuppression(
        inj.records[0].hours_ago,
    );
    if (suppression >= 0.4) return null;

    db.markAlertSent("purine_sentry", date) catch {};
    return std.fmt.bufPrint(
        buf,
        "\xF0\x9F\x94\x94 Purine Sentry!"
            ++ " T\xC5\x82umienie spad\xC5\x82o"
            ++ " do {d:.0}%."
            ++ "\nPowracaj\xC4\x85cy apetyt"
            ++ " = ryzyko z\xC5\x82amania"
            ++ " bufora purynowego."
            ++ "\nTrzymaj si\xC4\x99"
            ++ " nabia\xC5\x82u i WPI!",
        .{suppression * 100},
    ) catch null;
}

pub fn checkInjection(
    db: database.Db,
    date: []const u8,
    hour: u8,
    buf: []u8,
) ?[]const u8 {
    if (hour < 8 or hour > 10) return null;

    const days = (db.daysSinceInjection(date) catch
        return null) orelse return null;

    if (days >= 7) {
        if (db.isAlertSentToday(
            "injection_due",
            date,
        ) catch false) return null;
        db.markAlertSent(
            "injection_due",
            date,
        ) catch {};
        return std.fmt.bufPrint(
            buf,
            "\xF0\x9F\x92\x89 Czas na zastrzyk"
                ++ " Mounjaro!"
                ++ "\nOstatni: {d} dni temu."
                ++ "\nApetyt wraca"
                ++ " \xE2\x80\x94 nie czekaj.",
            .{days},
        ) catch null;
    }

    if (db.isAlertSentToday(
        "injection_phase",
        date,
    ) catch false) return null;
    db.markAlertSent(
        "injection_phase",
        date,
    ) catch {};

    if (days <= 2) {
        return std.fmt.bufPrint(
            buf,
            "\xF0\x9F\x92\x89 Dzie\xC5\x84 {d}"
                ++ " po zastrzyku."
                ++ "\nFaza wch\xC5\x82aniania."
                ++ " Mo\xC5\xBCliwe nudno\xC5\x9Bci"
                ++ " i zmniejszony apetyt."
                ++ "\nJedz ma\xC5\x82o,"
                ++ " ale regularnie.",
            .{days},
        ) catch null;
    } else if (days <= 5) {
        return std.fmt.bufPrint(
            buf,
            "\xF0\x9F\x8E\xAF Dzie\xC5\x84 {d}"
                ++ " po zastrzyku."
                ++ "\nSzczyt t\xC5\x82umienia"
                ++ " apetytu."
                ++ "\nKorzystaj z okna"
                ++ " \xE2\x80\x94 to najlepszy"
                ++ " czas na redukcj\xC4\x99.",
            .{days},
        ) catch null;
    } else {
        return std.fmt.bufPrint(
            buf,
            "\xF0\x9F\x93\x88 Dzie\xC5\x84 {d}"
                ++ " po zastrzyku."
                ++ "\nApetyt wraca."
                ++ " Uwa\xC5\xBCaj na impulsy!"
                ++ "\nTrzymaj si\xC4\x99"
                ++ " planu makro.",
            .{days},
        ) catch null;
    }
}
