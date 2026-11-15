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

    @Environment(\.colorScheme) private var colorScheme

    // GÖRÜNÜM (15 Kasım, L tasarım): Form korunur (seçiciler, tarih), ama zemini ScreenBackground, satırları yarı şeffaf kart rengi, vurgu turuncu.
    //   İŞLEV DEĞİŞMEDİ: aynı taslak (draft), Temizle / Uygula.
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        let rowFill = palette.cardSurface.opacity(0.7)
        NavigationStack {
            Form {
                Section("Varış") {
                    Picker("Varış ili", selection: $draft.toCityId) {
                        Text("Tümü").tag(0)
                        ForEach(cities) { Text($0.name).tag($0.id) }
                    }
                }
                .listRowBackground(rowFill) // [SWIFT] bölümdeki tüm satırların zemini
                // KONUM (15 Kasım): konumuma uzaklık — fiyat, araç, tarih gibi diğer filtrelerle BİRLİKTE çalışır | konum yalnız bu aramada kullanılır
                Section {
                    Picker("Bana uzaklık", selection: $draft.maxDistanceKm) {
                        Text("Farketmez").tag(Int?.none)
                        ForEach(OpenListingsFilter.distanceOptions, id: \.self) { Text("\($0) km içinde").tag(Int?.some($0)) }
                    }
                } header: { Text("Konum") } footer: { Text("Kalkış noktasının konumuna kuş uçuşu uzaklığı. Konumun kaydedilmez.") }
                .listRowBackground(rowFill)
                Section("Fiyat (₺)") {
                    TextField("En az", value: $draft.minBudget, format: .number).keyboardType(.numberPad)
                    TextField("En çok", value: $draft.maxBudget, format: .number).keyboardType(.numberPad)
                }
                .listRowBackground(rowFill)
                // AĞIRLIK (15 Kasım)
                Section("Yük ağırlığı (kg)") {
                    TextField("En az", value: $draft.minWeightKg, format: .number).keyboardType(.numberPad)
                    TextField("En çok", value: $draft.maxWeightKg, format: .number).keyboardType(.numberPad)
                }
                .listRowBackground(rowFill)
                Section("Araç") {
                    Picker("Araç tipi", selection: $draft.vehicleType) {
                        Text("Hepsi").tag("")
                        ForEach(VehicleType.vehicleOptions) { Text($0.title).tag($0.rawValue) } // Farketmez filtre değil; "Farketmez" ilanlar her filtrede zaten görünür (sunucu)
                    }
                    // 15 Kasım: yalnız araçlarıma uygun ilanlar (ilanın istediği tür araçlarımdan birinde var ya da "Farketmez") ⮕ sunucu matchMyVehicles
                    Toggle("Yalnız araçlarıma uygun", isOn: $draft.matchMyVehicles)
                    // Sıralama buradan KALDIRILDI (15 Kasım): ana ekranda filtreden ayrı "Sırala" menüsü (sahibinden tarzı)
                }
                .listRowBackground(rowFill)
                Section("Yükleme tarihi") {
                    Toggle("Bu tarihten sonra", isOn: $useFrom)
                    if useFrom { DatePicker("Başlangıç", selection: $fromDate, displayedComponents: .date) }
                    Toggle("Bu tarihten önce", isOn: $useTo)
                    if useTo { DatePicker("Bitiş", selection: $toDate, displayedComponents: .date) }
                }
                .listRowBackground(rowFill)
            }
            .foregroundStyle(palette.title)
            .themedScreen() // ⮕ Design/FormStyle.swift
            .navigationTitle("Filtre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Temizle") { clear() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Uygula") { apply() }.bold() }
            }
        }
    }

    private func clear() {
        draft = OpenListingsFilter(fromCityId: draft.fromCityId, fromDistrictId: draft.fromDistrictId, sort: draft.sort) // sıralama ana ekrandaki menüde, temizlemede korunur
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
