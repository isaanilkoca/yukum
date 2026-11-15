//
//  VehiclesView.swift
//  Yukum
//
//  Araçlarım (15 Kasım, yönetici: "içerde araç kaydetme sayfası olmalı; birden fazla aracı olabilir; plakası ve türüne göre kaydedip
//  araçlarım sayfası olmalı, düzenleyebilmeli; plaka bilgisi de alınmalı").
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: VehiclesView ───────────────────────────────────────────
// │ VIEWMODEL : ViewModels/VehiclesViewModel → VehicleService → /api/v1/vehicles
// │ AÇAN      : HomeView (Taşımacı alt satırı "Araçlarım") | ListingDetailView ("Araç ekle": aracı olmadan teklif verilemez)
// │ İŞLEMLER  : "+ Araç ekle" / karta dokun → VehicleFormSheet | sola kaydır → Sil
// │ ANİMASYON : ekle/düzenle → lastik izi | sil → kamyondan koli boşalır (Taşımacı işaretleri, Design/ActionFeedback)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [VehiclesView]: HomeView, ListingDetailView
struct VehiclesView: View {
    var startAdding = false // true: açılır açılmaz ekleme sayfası (teklif ekranından "Araç ekle" ile gelindiyse)

    @State private var viewModel = VehiclesViewModel()
    @State private var editing: Vehicle?       // dolunca düzenleme sayfası
    @State private var adding = false           // ekleme sayfası
    @State private var feedback: ActionFeedback?
    @State private var busy = false
    @State private var loaded = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        List {
            Button { adding = true } label: { AccentButtonLabel(title: "+ Araç ekle") } // ⮕ Design/FormStyle.swift
                .buttonStyle(.plain)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)

            if let message = viewModel.errorMessage {
                FormMessage(text: message, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }

            if viewModel.vehicles.isEmpty && !loaded {
                LoadingCard().listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if viewModel.vehicles.isEmpty {
                EmptyStateCard(icon: "truck.box", title: "Henüz aracın yok", detail: "Teklif verebilmek için en az bir aracını ekle.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }

            ForEach(viewModel.vehicles) { vehicle in
                Button { editing = vehicle } label: { row(vehicle, palette) } // dokun → düzenle
                    .buttonStyle(.plain)
                    .themedRow() // ⮕ Design/FormStyle.swift
                    .swipeActions {
                        Button("Sil", role: .destructive) {
                            Task {
                                busy = true
                                let ok = await viewModel.delete(vehicle) // ⮕ VehiclesViewModel.delete → DELETE /api/v1/vehicles/{id}
                                busy = false
                                if ok { feedback = ActionFeedback(.unload, "Araç silindi") }
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .busyIndicator(busy)
        .navigationTitle("Araçlarım")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(); loaded = true
            if startAdding && viewModel.vehicles.isEmpty { adding = true }
        }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $adding) { form(nil) }
        .sheet(item: $editing) { vehicle in form(vehicle) }
        .actionFeedback($feedback)
    }

    private func form(_ vehicle: Vehicle?) -> some View {
        VehicleFormSheet(vehicle: vehicle) { type, plate, capacity, brand, model, year in
            let error = await viewModel.save(editing: vehicle, type: type, plate: plate, capacity: capacity, brand: brand, model: model, year: year) // ⮕ VehiclesViewModel.save
            if error == nil { feedback = ActionFeedback(.track, vehicle == nil ? "Araç eklendi" : "Araç güncellendi") }
            return error
        }
    }

    // Satır: solda gerçek plaka görünümü, yanında tür ve kapasite
    private func row(_ vehicle: Vehicle, _ palette: Palette) -> some View {
        HStack(spacing: 14) {
            PlateBadge(plate: vehicle.plateNumber)
            VStack(alignment: .leading, spacing: 3) {
                Label(vehicle.typeTitle, systemImage: "truck.box.fill").font(.subheadline.bold()).foregroundStyle(palette.title)
                // 15 Kasım: marka · model · yıl | eski kayıtta eksikse uyarı (teklif verirken sunucu da ister)
                if let details = vehicle.detailsText {
                    Text(details).font(.caption.weight(.semibold)).foregroundStyle(palette.label)
                } else {
                    Label("Marka, model, yıl eksik — dokun, tamamla", systemImage: "exclamationmark.triangle.fill").font(.caption.weight(.semibold)).foregroundStyle(palette.danger)
                }
                Text(vehicle.capacityKg.map { "\($0.formatted()) kg kapasite" } ?? "Kapasite girilmedi")
                    .font(.caption).foregroundStyle(palette.label.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(palette.accent)
        }
    }
}

// BU GÖRÜNÜM: Türkiye plakası görünümü: beyaz zemin, siyah çerçeve, solda mavi "TR" şeridi
// ⮕ KULLANIM [PlateBadge]: VehiclesView
struct PlateBadge: View {
    let plate: String
    var body: some View {
        HStack(spacing: 0) {
            Text("TR").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 16).frame(maxHeight: .infinity)
                .background(Color(red: 0.0, green: 0.22, blue: 0.62))
            Text(plate).font(.system(size: 15, weight: .heavy, design: .monospaced)).foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
        }
        .frame(height: 30)
        .background(.white, in: .rect(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.black, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// BU SAYFA: araç ekle / düzenle | onSave hata mesajı döndürür (nil = başarılı → kapanır)
// ⮕ KULLANIM [VehicleFormSheet]: VehiclesView
struct VehicleFormSheet: View {
    let vehicle: Vehicle?
    let onSave: (_ type: String, _ plate: String, _ capacity: String, _ brand: String, _ model: String, _ year: String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var typeTitle = VehicleType.truck.title
    @State private var plate = ""
    @State private var capacity = ""
    @State private var brand = ""   // 15 Kasım: zorunlu
    @State private var model = ""   // 15 Kasım: zorunlu
    @State private var year = ""    // 15 Kasım: zorunlu (aracın yaşı)
    @State private var message: String?
    @State private var saving = false

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormCard { // ⮕ Design/FormStyle.swift
                        Text("Araç türü").font(.footnote.weight(.semibold)).foregroundStyle(palette.label)
                        FlowChips(items: VehicleType.vehicleOptions.map(\.title), selected: $typeTitle) // Farketmez yok (aracın türü olamaz) // ⮕ Views/CancelRequestSheet.swift › FlowChips
                        LabeledInput(label: "Plaka", systemImage: "number") {
                            TextField("34 ABC 123", text: $plate)
                                .textInputAutocapitalization(.characters).autocorrectionDisabled() // plaka büyük harf, düzeltme yok
                        }
                        // MARKA / MODEL / YIL (15 Kasım, zorunlu): Yük Veren teklifte ve profilde görür, kaliteli araç tercih edebilir
                        LabeledInput(label: "Marka", systemImage: "car.fill") {
                            TextField("ör. Mercedes-Benz", text: $brand).textInputAutocapitalization(.words)
                        }
                        LabeledInput(label: "Model", systemImage: "tag.fill") {
                            TextField("ör. Actros 1845", text: $model).textInputAutocapitalization(.words)
                        }
                        LabeledInput(label: "Model yılı", systemImage: "calendar") {
                            TextField("ör. 2019", text: $year).keyboardType(.numberPad)
                        }
                        LabeledInput(label: "Kapasite (kg, isteğe bağlı)", systemImage: "scalemass.fill") {
                            TextField("Örn. 24000", text: $capacity).keyboardType(.numberPad)
                        }
                    }
                    if let message { FormMessage(text: message, isError: true) }
                    Button {
                        Task {
                            saving = true
                            let type = VehicleType.vehicleOptions.first { $0.title == typeTitle }?.rawValue ?? ""
                            message = await onSave(type, plate, capacity, brand, model, year)
                            saving = false
                            if message == nil { dismiss() }
                        }
                    } label: { AccentButtonLabel(title: vehicle == nil ? "Aracı ekle" : "Kaydet", isLoading: saving, loadingTitle: "Kaydediliyor…") }
                    .disabled(saving)
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle(vehicle == nil ? "Araç Ekle" : "Aracı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } } }
        }
        .presentationDetents([.large]) // 15 Kasım: marka/model/yıl ile form uzadı, tam sayfa açılır
        .onAppear { // düzenlemede mevcut değerlerle dolar
            guard let vehicle else { return }
            typeTitle = vehicle.typeTitle
            plate = vehicle.plateNumber
            capacity = vehicle.capacityKg.map(String.init) ?? ""
            brand = vehicle.brand ?? ""
            model = vehicle.model ?? ""
            year = vehicle.year.map(String.init) ?? ""
        }
    }
}
