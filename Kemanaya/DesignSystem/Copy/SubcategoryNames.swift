import Foundation
import KemanayaCore

/// The name a subcategory goes by on screen (D-076): a seeded subcategory whose stored name is still its
/// Indonesian seed name shows its name from the String Catalog in the app language (Makan → "Food"); any
/// other name is the user's and shows as stored. The store and backups always keep the stored name.
///
/// Every screen, VoiceOver label and export goes through here, so one rule decides the name everywhere.
/// It resolves in the app language (the iPhone's or the per-app language, D-076), like `String(localized:)`.
nonisolated enum SubcategoryNames {
    /// The name shown for a subcategory with this `id` and `storedName`; also for a rollup snapshot's id
    /// and name (D-017, D-066).
    static func shown(id: UUID, storedName: String) -> String {
        guard let entry = SeedData.entry(matching: id, storedName: storedName), let resource = resource(for: entry) else {
            return storedName
        }
        return String(localized: resource)
    }

    /// The names a subcategory goes by, shown first: the shown name and, when it differs, the stored one.
    /// Search matches either (D-076), and a new name may match neither.
    static func all(id: UUID, storedName: String) -> [String] {
        let shown = shown(id: id, storedName: storedName)
        return shown == storedName ? [shown] : [shown, storedName]
    }

    /// The shown name of the seed entry stored as `indonesianName`, for illustrations such as the
    /// onboarding's sample cards. The name itself when the seed has no such entry.
    static func seed(_ indonesianName: String) -> String {
        guard let entry = SeedData.sections.joined().first(where: { $0.name == indonesianName }) else { return indonesianName }
        return shown(id: entry.id, storedName: entry.name)
    }

    /// The catalog entry of a seed name (D-008). Every ``SeedData`` entry has one; a test checks it.
    /// English names follow D-007: one word, at most ten characters, by purpose, never a brand.
    static func resource(for entry: SeedData.Entry) -> LocalizedStringResource? {
        switch entry.name {
        // Pemasukan (income)
        case "Gaji": LocalizedStringResource("subcategory.seed.gaji", defaultValue: "Gaji", comment: "Default income subcategory: salary, the regular pay from a job. One word, at most 10 characters (D-007).")
        case "Bonus": LocalizedStringResource("subcategory.seed.bonus", defaultValue: "Bonus", comment: "Default income subcategory: bonuses, including the holiday allowance (THR). One word, at most 10 characters (D-007).")
        case "Sampingan": LocalizedStringResource("subcategory.seed.sampingan", defaultValue: "Sampingan", comment: "Default income subcategory: side jobs and freelance work. One word, at most 10 characters (D-007).")
        case "Usaha": LocalizedStringResource("subcategory.seed.usaha", defaultValue: "Usaha", comment: "Default income subcategory: income from one's own business. One word, at most 10 characters (D-007).")
        case "Investasi": LocalizedStringResource("subcategory.seed.investasi", defaultValue: "Investasi", comment: "Default income subcategory: returns from investments (dividends, interest, gains). One word, at most 10 characters (D-007).")
        case "Hadiah": LocalizedStringResource("subcategory.seed.hadiah", defaultValue: "Hadiah", comment: "Default income subcategory: money received as a gift. Must differ from the expense subcategory Kado (presents given). One word, at most 10 characters (D-007).")
        case "Refund": LocalizedStringResource("subcategory.seed.refund", defaultValue: "Refund", comment: "Default income subcategory: money refunded for a purchase. One word, at most 10 characters (D-007).")
        case "Lainnya": LocalizedStringResource("subcategory.seed.lainnya", defaultValue: "Lainnya", comment: "Default income subcategory: any other income. One word, at most 10 characters (D-007).")
        // Kebutuhan (needs)
        case "Makan": LocalizedStringResource("subcategory.seed.makan", defaultValue: "Makan", comment: "Default needs subcategory: everyday meals. Eating out for fun is the wants subcategory Nongkrong. One word, at most 10 characters (D-007).")
        case "Dapur": LocalizedStringResource("subcategory.seed.dapur", defaultValue: "Dapur", comment: "Default needs subcategory: kitchen groceries (vegetables, rice, cooking supplies). One word, at most 10 characters (D-007).")
        case "Galon": LocalizedStringResource("subcategory.seed.galon", defaultValue: "Galon", comment: "Default needs subcategory: refills of the big drinking-water jug (galon). Not the unit of volume. One word, at most 10 characters (D-007).")
        case "Gas": LocalizedStringResource("subcategory.seed.gas", defaultValue: "Gas", comment: "Default needs subcategory: LPG cooking gas canisters, not petrol (that is Bensin). One word, at most 10 characters (D-007).")
        case "Listrik": LocalizedStringResource("subcategory.seed.listrik", defaultValue: "Listrik", comment: "Default needs subcategory: the electricity bill or prepaid tokens. One word, at most 10 characters (D-007).")
        case "Air": LocalizedStringResource("subcategory.seed.air", defaultValue: "Air", comment: "Default needs subcategory: the tap water bill (PDAM). One word, at most 10 characters (D-007).")
        case "WiFi": LocalizedStringResource("subcategory.seed.wifi", defaultValue: "WiFi", comment: "Default needs subcategory: the home internet bill. One word, at most 10 characters (D-007).")
        case "Pulsa": LocalizedStringResource("subcategory.seed.pulsa", defaultValue: "Pulsa", comment: "Default needs subcategory: mobile phone credit and data plans. One word, at most 10 characters (D-007).")
        case "Sewa": LocalizedStringResource("subcategory.seed.sewa", defaultValue: "Sewa", comment: "Default needs subcategory: rent for a house, room or boarding house. One word, at most 10 characters (D-007).")
        case "Cicilan": LocalizedStringResource("subcategory.seed.cicilan", defaultValue: "Cicilan", comment: "Default needs subcategory: loan and credit instalments. One word, at most 10 characters (D-007).")
        case "Ojol": LocalizedStringResource("subcategory.seed.ojol", defaultValue: "Ojol", comment: "Default needs subcategory: app-hailed motorbike or car rides. Name the purpose, never a brand. One word, at most 10 characters (D-007).")
        case "Bensin": LocalizedStringResource("subcategory.seed.bensin", defaultValue: "Bensin", comment: "Default needs subcategory: petrol for one's own vehicle. One word, at most 10 characters (D-007).")
        case "Parkir": LocalizedStringResource("subcategory.seed.parkir", defaultValue: "Parkir", comment: "Default needs subcategory: parking fees. One word, at most 10 characters (D-007).")
        case "Tol": LocalizedStringResource("subcategory.seed.tol", defaultValue: "Tol", comment: "Default needs subcategory: toll road fees. One word, at most 10 characters (D-007).")
        case "Transport": LocalizedStringResource("subcategory.seed.transport", defaultValue: "Transport", comment: "Default needs subcategory: public transport (train, bus). One word, at most 10 characters (D-007).")
        case "Kesehatan": LocalizedStringResource("subcategory.seed.kesehatan", defaultValue: "Kesehatan", comment: "Default needs subcategory: health costs (medicine, doctor). One word, at most 10 characters (D-007).")
        case "Pendidikan": LocalizedStringResource("subcategory.seed.pendidikan", defaultValue: "Pendidikan", comment: "Default needs subcategory: education (school fees, courses, books). One word, at most 10 characters (D-007).")
        case "Asuransi": LocalizedStringResource("subcategory.seed.asuransi", defaultValue: "Asuransi", comment: "Default needs subcategory: insurance premiums. One word, at most 10 characters (D-007).")
        case "Laundry": LocalizedStringResource("subcategory.seed.laundry", defaultValue: "Laundry", comment: "Default needs subcategory: laundry services. One word, at most 10 characters (D-007).")
        case "Sedekah": LocalizedStringResource("subcategory.seed.sedekah", defaultValue: "Sedekah", comment: "Default needs subcategory: charity and religious giving, a commitment. One word, at most 10 characters (D-007).")
        case "Rumah": LocalizedStringResource("subcategory.seed.rumah", defaultValue: "Rumah", comment: "Default needs subcategory: household supplies and cleaning. One word, at most 10 characters (D-007).")
        case "Servis": LocalizedStringResource("subcategory.seed.servis", defaultValue: "Servis", comment: "Default needs subcategory: repairs and servicing (vehicle, appliances). One word, at most 10 characters (D-007).")
        // Keinginan (wants)
        case "Kopi": LocalizedStringResource("subcategory.seed.kopi", defaultValue: "Kopi", comment: "Default wants subcategory: coffee and café drinks. One word, at most 10 characters (D-007).")
        case "Jajan": LocalizedStringResource("subcategory.seed.jajan", defaultValue: "Jajan", comment: "Default wants subcategory: snacks and street food bought on a whim. One word, at most 10 characters (D-007).")
        case "Nongkrong": LocalizedStringResource("subcategory.seed.nongkrong", defaultValue: "Nongkrong", comment: "Default wants subcategory: eating and hanging out with friends at restaurants or cafés. One word, at most 10 characters (D-007).")
        case "Delivery": LocalizedStringResource("subcategory.seed.delivery", defaultValue: "Delivery", comment: "Default wants subcategory: food ordered for delivery. One word, at most 10 characters (D-007).")
        case "Olshop": LocalizedStringResource("subcategory.seed.olshop", defaultValue: "Olshop", comment: "Default wants subcategory: online shopping. One word, at most 10 characters (D-007).")
        case "Fashion": LocalizedStringResource("subcategory.seed.fashion", defaultValue: "Fashion", comment: "Default wants subcategory: clothes, shoes and accessories. One word, at most 10 characters (D-007).")
        case "Skincare": LocalizedStringResource("subcategory.seed.skincare", defaultValue: "Skincare", comment: "Default wants subcategory: skincare and beauty products. One word, at most 10 characters (D-007).")
        case "Hiburan": LocalizedStringResource("subcategory.seed.hiburan", defaultValue: "Hiburan", comment: "Default wants subcategory: entertainment and leisure (cinema, concerts, outings). One word, at most 10 characters (D-007).")
        case "Streaming": LocalizedStringResource("subcategory.seed.streaming", defaultValue: "Streaming", comment: "Default wants subcategory: video and music streaming subscriptions. One word, at most 10 characters (D-007).")
        case "Game": LocalizedStringResource("subcategory.seed.game", defaultValue: "Game", comment: "Default wants subcategory: video games and in-game purchases. One word, at most 10 characters (D-007).")
        case "Hobi": LocalizedStringResource("subcategory.seed.hobi", defaultValue: "Hobi", comment: "Default wants subcategory: hobbies. One word, at most 10 characters (D-007).")
        case "Gadget": LocalizedStringResource("subcategory.seed.gadget", defaultValue: "Gadget", comment: "Default wants subcategory: gadgets and electronics. One word, at most 10 characters (D-007).")
        case "Liburan": LocalizedStringResource("subcategory.seed.liburan", defaultValue: "Liburan", comment: "Default wants subcategory: holidays and travel. One word, at most 10 characters (D-007).")
        case "Kado": LocalizedStringResource("subcategory.seed.kado", defaultValue: "Kado", comment: "Default wants subcategory: presents bought for others. Must differ from the income subcategory Hadiah (gifts received). One word, at most 10 characters (D-007).")
        default: nil
        }
    }
}

extension Subcategory {
    /// The name shown everywhere (D-076): see ``SubcategoryNames``. Use ``name`` only for the stored value
    /// (saving, backups, accessibility identifiers).
    nonisolated var displayName: String {
        SubcategoryNames.shown(id: id, storedName: name)
    }
}
