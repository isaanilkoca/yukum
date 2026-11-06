//
//  OpenListingsFilterView.swift
//  Yukum
//

import SwiftUI

// Taşımacı "Filtre" sayfası (alttan açılır) | filtrenin KOPYASI (draft) üzerinde çalışır, "Uygula"ya basınca onApply ile ViewModel'e verir
// NEDEN kopya: her tuşta sunucuya istek gitmesin, vazgeçilince (Kapat) ana liste değişmesin
// BAĞLANTI: Views/HomeView .sheet açar | filtre kalıbı: Models/Listings/OpenListingsFilter | seçenekler: ListingSort, VehicleType, City
// ÇIKTI: onApply(filter) → HomeView → viewModel.filter = filter → reloadKey değişir → load() sayfa 1'den yeniler
struct OpenListingsFilterView: View {
    @Environment(\.dismiss) private var dismiss // [SWIFT]: sayfayı kapatır
    let cities: [City] // HomeViewModel.cities (zaten yüklü)
    let onApply: (OpenListingsFilter) -> Void // closure [SWIFT]: "Uygula"da çağrılacak iş, HomeView verir

    @State private var draft: OpenListingsFilter // düzenlenen kopya
    @State private var useFrom: Bool // tarih alanı açık mı
    @State private var useTo: Bool
    @State private var fromDate: Date
    @State private var toDate: Date

    init(filter: OpenListingsFilter, cities: [City], onApply: @escaping (OpenListingsFilter) -> Void) {
        self.cities = cities
        self.onApply = onApply
        _draft = State(initialValue: filter) // _x = State'in kendisi (elle başlatma)
        _useFrom = State(initialValue: filter.pickupFrom != nil)
        _useTo = State(initialValue: filter.pickupTo != nil)
        _fromDate = State(initialValue: filter.pickupFrom.flatMap(Self.parse) ?? Date())
        _toDate = State(initialValue: filter.pickupTo.flatMap(Self.parse) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form { // Form [SWIFT]: ayar tarzı gruplu liste
                Section("Varış") {
                    Picker("Varış ili", selection: $draft.toCityId) {
                        Text("Tümü").tag(0) // 0 = filtre yok
                        ForEach(cities) { Text($0.name).tag($0.id) }
                    }
                }
                Section("Fiyat (₺)") {
                    // value + format [SWIFT]: yazıyı Int?'e çevirir | boş bırakılırsa nil = filtre yok
                    TextField("En az", value: $draft.minBudget, format: .number).keyboardType(.numberPad)
                    TextField("En çok", value: $draft.maxBudget, format: .number).keyboardType(.numberPad)
                }
                Section("Araç ve sıralama") {
                    Picker("Araç tipi", selection: $draft.vehicleType) {
                        Text("Hepsi").tag("") // "" = filtre yok
                        ForEach(VehicleType.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("Sıralama", selection: $draft.sort) {
                        Text("Varsayılan").tag(ListingSort?.none) // nil = sunucu seçer
                        ForEach(ListingSort.allCases) { Text($0.title).tag(ListingSort?.some($0)) } // Optional olduğu için tag da Optional
                    }
                }
                Section("Yükleme tarihi") {
                    Toggle("Bu tarihten sonra", isOn: $useFrom)
                    if useFrom { DatePicker("Başlangıç", selection: $fromDate, displayedComponents: .date) }
                    Toggle("Bu tarihten önce", isOn: $useTo)
                    if useTo { DatePicker("Bitiş", selection: $toDate, displayedComponents: .date) }
                }
            }
            .navigationTitle("Filtre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Temizle") { clear() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Uygula") { apply() }.bold() }
            }
        }
    }

    // clear: bu sayfadaki alanları boşaltır | kalkış ili/ilçesi ana ekranda durur, ona dokunulmaz
    private func clear() {
        draft = OpenListingsFilter(fromCityId: draft.fromCityId, fromDistrictId: draft.fromDistrictId)
        useFrom = false; useTo = false
    }

    // apply: tarihleri API biçimine (yyyy-MM-dd) çevirir, ters girilmişse yer değiştirir (API from > to'yu 400 ile reddeder)
    private func apply() {
        var from = fromDate, to = toDate
        if useFrom, useTo, from > to { swap(&from, &to) }
        draft.pickupFrom = useFrom ? Self.format(from) : nil
        draft.pickupTo = useTo ? Self.format(to) : nil
        onApply(draft)
        dismiss()
    }

    // DateFormatter [SWIFT, Foundation]: Date ↔ yazı | en_US_POSIX: telefon dilinden/takviminden bağımsız sabit biçim
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func format(_ date: Date) -> String { formatter.string(from: date) }
    static func parse(_ text: String) -> Date? { formatter.date(from: text) }
}
