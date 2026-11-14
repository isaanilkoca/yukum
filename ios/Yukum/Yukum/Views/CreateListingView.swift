//
//  CreateListingView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: CreateListingView (İlan Ver formu) ────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Başlık/Açıklama/Ağırlık/Bütçe/Araç/Tarih  →  viewModel.title, details, weightKg, budget, vehicleType, pickupDate ($ bağlar)  →  CreateListingRequest
// │ Kalkış/Varış il Picker'ı →  viewModel.cities, fromCityId, toCityId  →  CityService.cities()         →  GET /api/v1/cities               →  [City]
// │ Kalkış/Varış ilçe Picker →  viewModel.fromDistricts, toDistricts ← fromCityChanged/toCityChanged  →  CityService.districts()  →  GET /cities/{id}/districts  →  [District]
// │ İlanı Yayınla düğmesi    →  viewModel.submit()                  →  ListingService.create()         →  POST /api/v1/listings            →  CreateListingRequest → ListingResponse
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren'in ilan ver formu. Akış: alanları doldur → kontrol et → pakete koy → API'ye gönder
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, il→ilçe zinciri, doğrulama, paket hazırlama, gönderme ViewModels/CreateListingViewModel.swift'te.
// BAĞLANTI: HomeView.swift'teki "İlan Ver" NavigationLink'i bu ekranı açar (yalnız Shipper rolünde) | il/ilçe listesi Models/Services/CityService.swift'ten gelir
//           Paket kalıbı: Models/Listings/ → CreateListingRequest | gönderecek servis: Models/Services/ListingService.swift
// ⮕ KULLANIM [CreateListingView]: kullanır: HomeView › body
struct CreateListingView: View { // CreateListingView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: formun durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (form alanları kaybolmaz)
    // ⮕ KULLANIM [viewModel]: bağlar(okur+yazar): CreateListingView › body | okur: CreateListingView › body
    // listing: düzenlenecek ilan | nil = yeni ilan, bu yüzden HomeView'daki CreateListingView() çağrısı DEĞİŞMEZ
       // onSaved: düzenleme başarılı olunca çağrılır | ListingOffersView burada kendini de kapatır, eski başlık ekranda kalmasın
       // (() -> Void)? [SWIFT]: parametresiz, değer dönmeyen fonksiyon, boş (nil) olabilir
       private let onSaved: (() -> Void)?
       // @State: ekran yenilense de AYNI ViewModel yaşar | default değer yok, çünkü init'te listing'e göre kuruluyor
       @State private var viewModel: CreateListingViewModel
       init(listing: Listing? = nil, onSaved: (() -> Void)? = nil) {
           // _viewModel [SWIFT]: @State'in kendisine (kutusuna) ulaşır | State(initialValue:) ilk değeri verir | BAĞLANTI: ListingOffersView.init aynı kalıbı kullanıyor
           _viewModel = State(initialValue: CreateListingViewModel(editing: listing)) // CreateListingViewModel.init(editing:) → alanları ilanla doldurur
           self.onSaved = onSaved
       }
    // ⮕ KULLANIM [dismiss]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemin hazır değerini al | dismiss: "bu ekranı kapat" komutu | ilan açılınca HomeView'a dönmek için
    @Environment(\.colorScheme) private var colorScheme // [SWIFT] açık/koyu mod → Palette
    @State private var feedback: ActionFeedback? // işlem sonrası koli bantlama ⮕ Design/ActionFeedback.swift

    // TASARIM (14 Kasım, kullanıcı: "siyah arka plan ve mavi düğmeler ana renklerle uyumlu olsun"):
    //   giriş/kayıt ekranlarıyla aynı dil — renk geçişi arka plan, yarı saydam kartlar (FormCard), etiketli simgeli kutular (LabeledInput),
    //   turuncu seçiciler (.tint) ve turuncu "İlanı yayınla" düğmesi (AccentButtonLabel) ⮕ hepsi Design/FormStyle.swift
    //   Alanlar üç kartta toplanır: YÜK (ne?), GÜZERGÂH (nereden nereye?), ARAÇ VE TARİH (nasıl, ne zaman?) → uzun form bölümlere ayrılır.
    //   Alanların bağları ve il→ilçe zinciri DEĞİŞMEDİ (aynı $viewModel.x ve .onChange'ler).

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField/Picker doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark) // ⮕ Design/DesignPalette.swift

        ZStack {
            // ARKA PLAN: giriş/kayıt ekranlarıyla aynı renk geçişi + iki bulanık ışık halesi (siyah düz zemin yerine)
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            SoftGlow(color: palette.glowA, width: 380, height: 320).offset(x: -120, y: -220)
            SoftGlow(color: palette.glowB, width: 360, height: 300).offset(x: 130, y: 220)

            ScrollView { // ScrollView [SWIFT]: uzun formda kaydırma
                VStack(alignment: .leading, spacing: 16) {

                    Text(viewModel.screenTitle) // "İlan Ver" / "İlanı Düzenle" | ⮕ CreateListingViewModel.screenTitle
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.title)
                        .padding(.top, 4)

                    // ---- KART 1: YÜK ----
                    section("Yük", palette) {
                        // LabeledInput(etiket, simge) { alan } ⮕ Design/FormStyle.swift | $ = iki yönlü bağ: yazılan doğrudan ViewModel'e gider
                        LabeledInput(label: "Başlık", systemImage: "shippingbox.fill") {
                            TextField("Örn. 20 palet zeytinyağı", text: $viewModel.title)
                        }
                        LabeledInput(label: "Açıklama (isteğe bağlı)", systemImage: "text.alignleft") {
                            TextField("Yük hakkında kısa not", text: $viewModel.details)
                        }
                        LabeledInput(label: "Ağırlık (kg)", systemImage: "scalemass.fill") {
                            TextField("Örn. 8000", text: $viewModel.weightKg).keyboardType(.numberPad) // .numberPad: yalnız rakam klavyesi
                        }
                    }

                    // ---- KART 2: GÜZERGÂH (önce il, il seçilince o ilin ilçeleri) ----
                    section("Güzergâh", palette) {
                        LabeledInput(label: "Kalkış ili", systemImage: "mappin.and.ellipse") {
                            // Picker [SWIFT]: açılır liste | selection: seçilen değer ViewModel'deki fromCityId'ye yazılır | ⮕ CreateListingViewModel.fromCityId
                            menuPicker("Kalkış ili", selection: $viewModel.fromCityId) {
                                Text("Seçiniz").tag(0) // tag(0): hiçbir şey seçilmemişken bu yazı görünür, değeri 0
                                ForEach(viewModel.cities) { city in Text(city.name).tag(city.id) } // ⮕ CreateListingViewModel.cities ← CityService.cities() → [City]
                            }
                            // .onChange [SWIFT]: değişken değişince BİR KEZ çalışır | il değişince ViewModel ilçe seçimini sıfırlar ve yeni ilin ilçelerini çeker
                            // Task [SWIFT]: .onChange bekleyemez, await yalnız Task içinde yazılır | ⮕ CreateListingViewModel.fromCityChanged → CityService.districts → fromDistricts
                            .onChange(of: viewModel.fromCityId) { _, newId in Task { await viewModel.fromCityChanged(to: newId) } }
                        }
                        if viewModel.fromCityId != 0 { // il seçilmeden ilçe kutusu çizilmez
                            LabeledInput(label: "Kalkış ilçesi", systemImage: "mappin") {
                                menuPicker("Kalkış ilçesi", selection: $viewModel.fromDistrictId) {
                                    Text("Seçiniz").tag(0)
                                    ForEach(viewModel.fromDistricts) { district in Text(district.name).tag(district.id) } // District: Models/Geography/
                                }
                            }
                        }

                        // VARIŞ: kalkıştaki bloğun aynısı, yalnız to... değişkenleri
                        LabeledInput(label: "Varış ili", systemImage: "flag.checkered") {
                            menuPicker("Varış ili", selection: $viewModel.toCityId) {
                                Text("Seçiniz").tag(0)
                                ForEach(viewModel.cities) { city in Text(city.name).tag(city.id) } // aynı 81 il
                            }
                            .onChange(of: viewModel.toCityId) { _, newId in Task { await viewModel.toCityChanged(to: newId) } } // ⮕ CreateListingViewModel.toCityChanged
                        }
                        if viewModel.toCityId != 0 {
                            LabeledInput(label: "Varış ilçesi", systemImage: "flag") {
                                menuPicker("Varış ilçesi", selection: $viewModel.toDistrictId) {
                                    Text("Seçiniz").tag(0)
                                    ForEach(viewModel.toDistricts) { district in Text(district.name).tag(district.id) }
                                }
                            }
                        }
                    }

                    // ---- KART 3: ARAÇ VE TARİH ----
                    section("Araç ve tarih", palette) {
                        LabeledInput(label: "İstenen araç", systemImage: "truck.box.fill") {
                            menuPicker("İstenen araç", selection: $viewModel.vehicleType) {
                                Text("Seçiniz").tag("") // tag(""): hiçbir şey seçilmemişken bu yazı görünür
                                ForEach(VehicleType.allCases) { type in Text(type.title).tag(type.rawValue) } // ⮕ Models/Vehicles/VehicleType.swift
                            }
                        }
                        LabeledInput(label: "Yükleme tarihi", systemImage: "calendar") {
                            // DatePicker [SWIFT]: tarih seçici | in: Date()... = bugünden öncesi seçilemez | .date: yalnız gün
                            // .labelsHidden() [SWIFT]: kendi etiketi gizlenir (etiket kutunun üstünde zaten var)
                            DatePicker("Yükleme tarihi", selection: $viewModel.pickupDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        LabeledInput(label: "Bütçe ₺ (isteğe bağlı)", systemImage: "turkishlirasign.circle.fill") {
                            TextField("Örn. 15000", text: $viewModel.budget).keyboardType(.numberPad)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage { FormMessage(text: errorMessage, isError: true) } // ⮕ Design/FormStyle.swift

                    // Düğme yalnız TETİKLEYİCİ: kontroller, paket hazırlama ve gönderme ViewModel.submit()'te
                    // başarıda ekran kapanır ve HomeView'a dönülür (HomeView listeyi ekran görününce kendisi yeniler)
                    Button { // Task [SWIFT]: düğmede await kullanmamızı sağlar; ekran donmaz
                        // BAŞARIDA (15 Kasım): önce koli kapanıp bantlanır (Yük Veren işareti), animasyon bitince ekran kapanır ⮕ Design/ActionFeedback.swift
                        Task {
                            if await viewModel.submit() { // ⮕ submit() → ListingService.update (düzenleme) / create (yeni)
                                feedback = ActionFeedback(.seal, viewModel.isEditing ? "İlan güncellendi" : "İlan yayında") { dismiss(); onSaved?() }
                            }
                        }
                    } label: {
                        AccentButtonLabel(title: viewModel.submitTitle, isLoading: viewModel.isLoading, loadingTitle: viewModel.isEditing ? "Güncelleniyor…" : "Yayınlanıyor…") // "İlanı Yayınla" / "İlanı Güncelle" | turuncu düğme ⮕ Design/FormStyle.swift
                    }
                    .disabled(viewModel.isLoading) // isLoading iken kilitli (çift tıklama olmasın)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively) // [SWIFT] kaydırınca klavye kapanır
        }
        .tint(palette.accent) // [SWIFT] seçiciler, tarih ve geri oku turuncu (mavi yerine)
        .navigationBarTitleDisplayMode(.inline)
        .actionFeedback($feedback) // ⮕ Design/ActionFeedback.swift: koli bantlama animasyonu, bitince then (dismiss + onSaved)
        .task { await viewModel.loadCities() } // .task [SWIFT]: ekran açılınca bir kez çalışır | il listesini API'den çeker | ⮕ CreateListingViewModel.loadCities() → CityService.cities()
    }

    // BU FONKSİYON: başlıklı bir kart (bölüm) çizer | @ViewBuilder [SWIFT]: süslü parantez içinde alt alta görünüm yazmayı sağlar
    private func section<Content: View>(_ title: String, _ palette: Palette, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(palette.title).padding(.leading, 4) // kartın üstündeki bölüm adı
            FormCard { content() } // ⮕ Design/FormStyle.swift
        }
    }

    // BU FONKSİYON: kutunun içinde tam genişlik, sola yaslı açılır menü (Picker) | Hashable [SWIFT]: seçenek değeri karşılaştırılabilir olmalı
    private func menuPicker<Value: Hashable, Options: View>(_ title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options) -> some View {
        Picker(title, selection: selection) { options() }
            .pickerStyle(.menu) // açılır menü | .pickerStyle [SWIFT]
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    CreateListingView()
}
