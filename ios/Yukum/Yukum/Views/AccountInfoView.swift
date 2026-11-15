//
//  AccountInfoView.swift
//  Yukum
//
//  Hesap Bilgilerim (15 Kasım, yönetici planı 7. adım): profil fotoğrafı + ad, telefon, il, hakkımda (+ Yük Veren'de firma/vergi).
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi
import PhotosUI   // [SWIFT] PhotosPicker: telefonun fotoğraf arşivinden seçim (izin istemez: yalnız seçilen fotoğraf uygulamaya verilir)

// ┌─ BAĞLANTI HARİTASI: AccountInfoView ───────────────────────────────────────
// │ VIEWMODEL : ViewModels/AccountInfoViewModel → AccountService → /api/v1/account/me, /api/v1/account/avatar
// │ AÇAN      : HomeView (alt satır "Hesap Bilgilerim", iki rol) | 8. adımda profil sayfasına taşınacak
// │ PARÇALAR  : Design/AvatarView (fotoğraf) | Design/FormStyle (FormCard, LabeledInput, AccentButtonLabel, FormMessage, busyIndicator)
// │ ANİMASYON : kaydet → rolün olumlu işareti (Yük Veren: koli bantlanır .seal | Taşımacı: lastik izi .track) — Design/ActionFeedback
// │ GERİ BİLDİRİM: onSaved(yeni ad) → HomeView selamlamadaki adı günceller (yeniden giriş gerekmez)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [AccountInfoView]: HomeView
struct AccountInfoView: View {
    var onSaved: (String) -> Void = { _ in } // kaydedince yeni görünen ad

    @State private var viewModel = AccountInfoViewModel()
    @State private var photoItem: PhotosPickerItem? // seçilen fotoğrafın "tutamağı" (baytlar henüz yüklenmedi)
    @State private var feedback: ActionFeedback?
    @State private var confirmRemovePhoto = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ScrollView {
            if let profile = viewModel.profile {
                VStack(alignment: .leading, spacing: 16) {
                    photoSection(profile, palette)
                    if let message = viewModel.errorMessage { FormMessage(text: message, isError: true) }
                    personalCard(profile, palette)
                    if profile.isShipper { companyCard } else { carrierStats(profile, palette) }
                    saveButton(profile)
                }
                .padding(20)
            } else if let message = viewModel.errorMessage {
                FormMessage(text: message, isError: true).padding(20)
            } else {
                LoadingCard().padding(20) // ⮕ Design/FormStyle.swift: ilk yükleme
            }
        }
        .scrollDismissesKeyboard(.interactively) // kaydırınca klavye kapanır
        .background { ScreenBackground() }
        .busyIndicator(viewModel.isPhotoBusy)    // fotoğraf yüklenirken/kaldırılırken "İşleniyor…"
        .navigationTitle("Hesap Bilgilerim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        // Fotoğraf seçilince: baytları al → ViewModel küçültüp yükler | loadTransferable [SWIFT]: seçilen öğeyi istenen türde (Data) getirir
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await viewModel.uploadAvatar(data) }
                photoItem = nil // aynı fotoğraf tekrar seçilebilsin
            }
        }
        .confirmationDialog("Profil fotoğrafı kaldırılsın mı?", isPresented: $confirmRemovePhoto, titleVisibility: .visible) {
            Button("Fotoğrafı kaldır", role: .destructive) { Task { await viewModel.removeAvatar() } }
        }
        .actionFeedback($feedback)
    }

    // ÜST: büyük yuvarlak fotoğraf + "Fotoğrafı değiştir" (PhotosPicker) + varsa "Kaldır"
    private func photoSection(_ profile: AccountProfile, _ palette: Palette) -> some View {
        VStack(spacing: 10) {
            AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 104) // ⮕ Design/AvatarView.swift
            HStack(spacing: 8) {
                // matching: .images → yalnız fotoğraflar (video yok)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(profile.avatarUrl == nil ? "Fotoğraf ekle" : "Değiştir", systemImage: "camera.fill")
                }
                .buttonStyle(ChipButtonStyle(.outline))
                if profile.avatarUrl != nil {
                    Button { confirmRemovePhoto = true } label: { Label("Kaldır", systemImage: "trash") }
                        .buttonStyle(ChipButtonStyle(.danger))
                }
            }
            Text(profile.isShipper ? "Yük Veren hesabı" : "Taşımacı hesabı").font(.caption).foregroundStyle(palette.label.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // KİŞİSEL: ad, e-posta (kilitli), telefon (değişirse şifre alanı açılır), il, hakkımda
    @ViewBuilder
    private func personalCard(_ profile: AccountProfile, _ palette: Palette) -> some View {
        @Bindable var viewModel = viewModel // $viewModel.alan bağları için
        FormCard {
            LabeledInput(label: profile.isShipper ? "Ad soyad / firma adı" : "Ad soyad", systemImage: "person.fill") {
                TextField("Ad soyad", text: $viewModel.fullName).textContentType(.name)
            }
            LabeledInput(label: "E-posta (değiştirilemez)", systemImage: "lock.fill") {
                Text(profile.email).foregroundStyle(palette.label.opacity(0.6)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
            LabeledInput(label: "Telefon", systemImage: "phone.fill") {
                TextField("0532 123 45 67", text: $viewModel.phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
            }
            // Telefon değişince açılır: giriş bilgisi değiştiği için sunucu mevcut şifreyi ister (AccountProfileHandlers.cs)
            if viewModel.phoneChanged {
                LabeledInput(label: "Mevcut şifre (telefon değişikliği için)", systemImage: "key.fill") {
                    SecureField("Şifren", text: $viewModel.currentPassword).textContentType(.password)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Picker(profile.isShipper ? "İl" : "Bulunduğun il", selection: $viewModel.cityId) {
                Text("Seçilmedi").tag(Int?.none) // tag [SWIFT]: seçilince bağlı değişkene yazılacak değer
                ForEach(viewModel.cities) { city in Text(city.name).tag(Int?.some(city.id)) }
            }
            .pickerStyle(.menu)
            .tint(palette.accent)
            VStack(alignment: .leading, spacing: 7) {
                Text("Hakkımda").font(.footnote.weight(.semibold)).foregroundStyle(palette.label)
                // axis: .vertical → yazdıkça büyüyen çok satırlı alan | lineLimit(3...6): en az 3, en çok 6 satır görünür
                TextField(profile.isShipper ? "Örn. Mersin'de narenciye ihracatı yapıyoruz." : "Örn. 10 yıllık tecrübe, frigorifik taşıma.",
                          text: $viewModel.about, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(palette.title).tint(palette.accent)
                    .padding(12)
                    .background(palette.fieldSurface, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.fieldBorder))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.phoneChanged)
    }

    // YÜK VEREN: fatura bilgileri (hepsi isteğe bağlı)
    private var companyCard: some View {
        @Bindable var viewModel = viewModel
        return FormCard {
            LabeledInput(label: "Firma adı (isteğe bağlı)", systemImage: "building.2.fill") {
                TextField("Firma adı", text: $viewModel.companyName)
            }
            LabeledInput(label: "Vergi no / T.C. kimlik no (isteğe bağlı)", systemImage: "number") {
                TextField("10 ya da 11 hane", text: $viewModel.taxNumber).keyboardType(.numberPad)
            }
            LabeledInput(label: "Vergi dairesi (isteğe bağlı)", systemImage: "doc.text.fill") {
                TextField("Vergi dairesi", text: $viewModel.taxOffice)
            }
        }
    }

    // TAŞIMACI: puan ve iş sayısı (salt okunur: karşı tarafların verdiği puanlardan hesaplanır)
    private func carrierStats(_ profile: AccountProfile, _ palette: Palette) -> some View {
        HStack(spacing: 12) {
            stat(value: (profile.ratingCount ?? 0) > 0 ? String(format: "%.1f", profile.averageRating ?? 0) : "—",
                 title: "Puan (\(profile.ratingCount ?? 0))", icon: "star.fill", palette)
            stat(value: "\(profile.completedJobCount ?? 0)", title: "Tamamlanan iş", icon: "checkmark.seal.fill", palette)
        }
    }
    private func stat(value: String, title: String, icon: String, _ palette: Palette) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(palette.accent)
            Text(value).font(.title3.bold()).foregroundStyle(palette.title)
            Text(title).font(.caption).foregroundStyle(palette.label.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .themedCard() // ⮕ Design/FormStyle.swift
    }

    // KAYDET: yalnız değişiklik varsa açık | başarıda rol animasyonu + HomeView'a yeni ad
    private func saveButton(_ profile: AccountProfile) -> some View {
        Button {
            Task {
                if await viewModel.save() { // ⮕ AccountInfoViewModel.save → PUT /api/v1/account/me
                    feedback = ActionFeedback(profile.isShipper ? .seal : .track, "Bilgiler kaydedildi")
                    onSaved(viewModel.fullName)
                }
            }
        } label: { AccentButtonLabel(title: "Kaydet", isLoading: viewModel.isSaving, loadingTitle: "Kaydediliyor…") }
        .disabled(viewModel.isSaving || !viewModel.hasChanges)
        .opacity(viewModel.hasChanges ? 1 : 0.5)
    }
}
