import Foundation

/// The subcategories a fresh install starts with (D-008) and the default Home pins (D-012).
///
/// Names are user data, not UI strings: they stay Indonesian and are not in the String Catalog (D-023).
/// Every entry has a fixed id, so a restore (D-019) can match seeded rows instead of duplicating them.
/// **Never change an id once shipped.**
public enum SeedData {
    /// Bump when the seed changes and ``Seeder`` gains a step for it.
    public static let version = 1

    public struct Entry: Equatable, Sendable {
        /// Becomes ``Subcategory/id``.
        public let id: UUID
        public let name: String
        public let emoji: String
        public let kind: TransactionKind
        public let group: ExpenseGroup?
    }

    /// Pemasukan, in D-008 order.
    public static let income: [Entry] = entries(kind: .income, group: nil, [
        ("E84A09B0-1D55-478F-9C05-3F03FBF6AD12", "Gaji", "💼"),
        ("8695CAD2-C055-4E36-8D2A-0739384F9D20", "Bonus", "🎉"),
        ("79CD032A-760F-4390-8A29-88DB18F5CB03", "Sampingan", "💻"),
        ("226B3B6D-3E01-4EAE-ADFF-9604D42069E2", "Usaha", "🏪"),
        ("530A495D-148F-493C-A413-F80EB95E6A72", "Investasi", "📈"),
        ("1BF56657-6CC5-4983-9C1A-6070A7BBCF52", "Hadiah", "🎁"),
        ("8E6CABBE-0EE7-49D8-AEB9-55EE99EE67A1", "Refund", "↩️"),
        ("25F3C240-A2E8-4899-B905-4D4E1DCAF87A", "Lainnya", "✨"),
    ])

    /// Kebutuhan, in D-008 order.
    public static let kebutuhan: [Entry] = entries(kind: .expense, group: .kebutuhan, [
        ("88A3D42E-103C-4B7F-A271-696E175AC398", "Makan", "🍚"),
        ("AD373D72-ED74-49EC-A3AA-B5A752CB249B", "Dapur", "🥬"),
        ("915F791D-CF2F-4E36-8967-37BAF8308AEA", "Galon", "💧"),
        ("E8CAADE6-AA65-4AA4-8F83-8DF1B67A4AD2", "Gas", "🔥"),
        ("66915C03-8336-43FC-B1DC-10323F78E535", "Listrik", "⚡"),
        ("A44BEEF0-9E3C-40B3-9666-F47053E65595", "Air", "🚰"),
        ("3152E1A0-BD92-4DDB-BC59-D3453F0B8B1A", "WiFi", "📶"),
        ("D88A2260-5EDC-4D93-8699-3B51DADAD759", "Pulsa", "📱"),
        ("C2B33DE7-678A-4CEE-B7A0-EE0BEEEEB034", "Sewa", "🏠"),
        ("97EAF9DC-4A42-416C-A6F9-D2EDFC50DFF8", "Cicilan", "💳"),
        ("E6CE1E54-B8C3-4935-8457-5CD36EEC3861", "Ojol", "🛵"),
        ("876549E8-2939-45A2-B1A5-2D772CE003FD", "Bensin", "⛽"),
        ("C6104700-E224-4303-9326-0C2F08D287B2", "Parkir", "🅿️"),
        ("469FBC5B-EBAA-43AF-B2AF-64E3180B8A36", "Tol", "🛣️"),
        ("927F41A9-9738-4517-BC32-5C235C30EBDA", "Transport", "🚆"),
        ("97E02076-EC49-448F-B0E6-C17A3545E969", "Kesehatan", "💊"),
        ("26C9EDB8-388F-40E7-936B-58EC119585BF", "Pendidikan", "📚"),
        ("C61CF31A-3964-491A-952E-95330B1D3FD9", "Asuransi", "🛡️"),
        ("124A3C4F-FF37-498F-872B-59CE19095920", "Laundry", "🧺"),
        ("39CAE885-84C9-4BA8-80FF-95483C9494CA", "Sedekah", "🤲"),
        ("AB7BB799-FA40-416D-B2F2-12B7675EAD33", "Rumah", "🧹"),
        ("E40C9FD2-1744-44BA-9EB3-3DD5ADC8E149", "Servis", "🔧"),
    ])

    /// Keinginan, in D-008 order.
    public static let keinginan: [Entry] = entries(kind: .expense, group: .keinginan, [
        ("35EAADA5-2960-46E0-9195-988270F359DB", "Kopi", "☕"),
        ("4FBD2C42-A708-4A80-919F-D552360FA76C", "Jajan", "🍿"),
        ("C63B3A9D-FEE8-418B-A1D8-7708BDCC072E", "Nongkrong", "🍽️"),
        ("721C24DF-38C5-493F-BB94-438044B4A47A", "Delivery", "🥡"),
        ("8DC45A6D-9AB1-4DF8-975C-00515623F9C9", "Olshop", "📦"),
        ("BACB0386-CF30-43B0-BA0B-46295A5887B0", "Fashion", "👕"),
        ("4EF99EEC-6FCA-4185-B3EB-FED466525306", "Skincare", "🧴"),
        ("93B68C9C-CECD-4BF6-BE52-394BC0092085", "Hiburan", "🎬"),
        ("89F2DCAD-F2A5-44A8-806A-EB7AAB77F933", "Streaming", "📺"),
        ("5C97C866-1962-4E73-8BD0-57F235B12317", "Game", "🎮"),
        ("BC6AE67C-51DC-486B-9FC5-B59273745C09", "Hobi", "🎨"),
        ("095652A1-5B2F-452C-86F3-3FB4121FBA0F", "Gadget", "🎧"),
        ("8DA169CA-35C5-45D7-B061-A43A3C406583", "Liburan", "🏖️"),
        ("F1602F9B-579B-4DC9-890D-1134C1A4F04A", "Kado", "🎁"),
    ])

    /// Every section in display order. `sortOrder` is the index within its section.
    public static let sections: [[Entry]] = [income, kebutuhan, keinginan]

    /// Expense subcategory names pinned on a fresh install, in Home order (D-012).
    public static let defaultPins: [String] = ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"]

    private static func entries(kind: TransactionKind, group: ExpenseGroup?, _ rows: [(String, String, String)]) -> [Entry] {
        rows.map { Entry(id: UUID(uuidString: $0.0)!, name: $0.1, emoji: $0.2, kind: kind, group: group) }
    }
}
