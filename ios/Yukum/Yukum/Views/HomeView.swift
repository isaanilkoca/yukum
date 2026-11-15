//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: HomeView (ana sayfa, iki rol) ─────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Yük Veren tasarımı       →  shipperHome + shipperBackground (bu dosyanın sonunda): selamlama, sade (3B yok, 15 Kasım), Design/TruckLoadView (3B dorse), "Yeni ilan ver", ilan kartları | renkler: Design/DesignPalette.swift
// │ Taşımacı tasarımı        →  carrierHome + carrierBackground (bu dosyanın sonunda): selamlama, "Yük ara" paneli (il/ilçe, Yakınımdakiler, Filtre), tabela başlık, rota kartları (Views/ListingRow › RouteCard) | arkada Design/TruckRoadView (dorse yanaşır, yük yığından alınır, bir kez oynar ve durur)
// │ Hoş Geldin yazısı        →  viewModel.user                     →  (servis yok)                    →  (LoginView'dan gelir)            →  LoginUser
// │ Yük Veren ilan listesi   →  viewModel.listings ← load()         →  ListingService.myListings()     →  GET /api/v1/listings/mine        →  [Listing]
// │ Taşımacı ilan listesi    →  viewModel.listings ← load()         →  ListingService.openListings()   →  GET /api/v1/listings?...         →  [Listing]
// │ İl / İlçe Picker'ları    →  cities, filterDistricts, filterCityId, filterDistrictId  →  CityService.cities() / districts()  →  GET /cities, /cities/{id}/districts  →  [City] / [District]
// │ Yakınımdakiler anahtarı  →  viewModel.nearMe, nearMeChanged(to:) (konum izni/konumu ViewModel'in Location sözleşmesinden)  →  load() → ListingService.openListings(lat,lon)  →  GET ...?lat=&lon=  →  Listing.distanceKm
// │ Kutu ikonundaki rozet    →  viewModel.unseenCount ← load()     →  OfferService.unseenCount()      →  GET /api/v1/offers/mine/unseen-count  →  UnseenCount
// │ Çıkış Yap                →  viewModel.signOut()                 →  AuthSession.signOut()           →  POST /api/v1/auth/logout         →  (yok)
// │ Oturum bitti uyarısı     →  NotificationCenter .sessionExpired  →  AuthSession yayınlar            →  -                                →  dismiss() ile giriş ekranına
// │ Satıra dokunma / ikonlar →  Yük Veren: ListingOffersView(listing:) | Taşımacı: ListingDetailView(listing:) | "Yeni ilan ver" → CreateListingView (tek yol, + kaldırıldı) | sol üst profil fotoğrafı → ProfileView (Eski Teklifler, Tekliflerim, Araçlarım, Beğendiklerim, Hesap — 15 Kasım, 8. adım)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: giriş sonrası ana ekran. Rol "Shipper" ise Yük Veren, değilse Taşımacı anasayfası gösterir.
// MVVM: bu dosya yalnız GÖRÜNÜM (ne çizilecek). Durum ve iş mantığı (hangi liste, hangi filtre, ne zaman yüklenir, hata yazısı) ViewModels/HomeViewModel.swift'te.
// BAĞLANTI: Views/LoginView.swift giriş başarılı olunca .fullScreenCover ile bu ekranı açar ve giriş yapan kullanıcıyı verir.
// ⮕ KULLANIM [HomeView]: kullanır: LoginView › body
struct HomeView: View { // HomeView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (her yenilemede yeni ViewModel oluşmaz)
    // @Observable olduğu için viewModel içindeki değişkenler değişince bu ekran kendiliğinden yenilenir
    // ⮕ KULLANIM [viewModel]: okur: HomeView › body | bağlar(okur+yazar): HomeView › body
    @State private var viewModel: HomeViewModel // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir


    // ⮕ KULLANIM [dismiss]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    // ⮕ KULLANIM [openURL]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer al | dismiss: "bu ekranı kapat" komutu | çıkışta kullanılır
    
    
    
    @State private var showNotifications = false // true → bildirim listesi açılır (telefondaki bildirime dokununca)
    @State private var showFilter = false // Filtre sayfası açık mı | true → .sheet görünür
    @State private var listLoaded = false // ilk liste yüklemesi bitti mi → bitmeden "Henüz ilan yok" yerine "Yükleniyor…" (15 Kasım, yönetici: loader)
    @Environment(\.colorScheme) private var colorScheme // [SWIFT] açık/koyu mod → Palette seçimi (Yük Veren tasarımı)
    @Environment(\.openURL) private var openURL // openURL: bir adresi açar | burada iOS Ayarlar uygulamasını açmak için kullanılır | openURL [SWIFT]: bir adresi açar (Ayarlar uygulaması gibi)

    // init: dışarıdan "user" verilir (LoginView: HomeView(user: user)), ViewModel burada oluşturulur
    // State(initialValue:): @State'i elle başlatma yolu | kalıbı: Models/Auth/ → struct LoginUser
    init(user: LoginUser) {
        _viewModel = State(initialValue: HomeViewModel(user: user))
    }

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable bir sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (Picker/Toggle seçimi doğrudan ViewModel'e yazılsın diye)
        @Bindable var viewModel = viewModel

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | NavigationLink'ler bunun içinde çalışır

            VStack(spacing: 24) { // elemanları alt alta dizer | VStack [SWIFT]: elemanları alt alta dizer

                // user.role API'den "Shipper" ya da "Carrier" gelir | yazımı API ile birebir aynı olmalı
                if viewModel.isShipper { // GÖRÜNÜM kararı: ekranda ne ÇİZİLECEK | Yük Veren tasarımlı ana ekranı görür (selamlama dahil, aşağıda shipperHome), Taşımacı else'teki ekranı

                    shipperHome // ⮕ aşağıdaki extension HomeView › shipperHome (L tasarım, 13 Kasım)

                } else { // Shipper değilse (Carrier)

                    carrierHome // ⮕ aşağıdaki extension HomeView › carrierHome (L tasarım, 14 Kasım: yol + yük teslim alma teması) | işlev eskisiyle aynı: il/ilçe, Yakınımdakiler, Filtre, sayfalı liste

                }
                
                // ALT SATIR KALDIRILDI (15 Kasım, 8. adım): Hesap Bilgilerim, Araçlarım, Gizlilik, Hesabı Sil, Çıkış → Views/ProfileView (sol üst profil fotoğrafı)

            }.padding() // .padding [SWIFT]: etrafında boşluk bırakır
            // Tam ekran arka plan, role göre: Yük Veren → yukarıdan dolan dorse | Taşımacı → yanaşıp yükü yerden teslim alan dorse (14 Kasım)
            .background { if viewModel.isShipper { shipperBackground } else { carrierBackground } } // ⮕ aşağıdaki extension'lar: shipperBackground / carrierBackground
            // .onReceive [SWIFT]: bir "yayını" dinler | oturum yenilenemezse (süre doldu, jeton iptal edildi/çalıntı sanıldı) AuthSession "sessionExpired" yayınlar
            // → ekran kapanır ve kullanıcı giriş ekranına döner (jeton zaten silindi) | NEDEN gerekli: arka plandaki istekler 401 alıp yenileyemediğinde kullanıcı boşta kalmasın
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in dismiss() } // ⮕ yayıncı: AuthSession.expireSession() (Models/Networking/Notification+SessionExpired.swift) | NotificationCenter [SWIFT]: uygulama içi anons panosu (biri yayınlar, ilgilenen dinler)
            

            .sheet(isPresented: $showFilter) { // .sheet [SWIFT]: alttan açılan sayfa | showFilter true olunca görünür
                OpenListingsFilterView(filter: viewModel.filter, cities: viewModel.cities) { viewModel.applyFilter($0) } // Uygula → HomeViewModel.applyFilter (uzaklık seçildiyse konum istenir) → reloadKey → load()
            }
            // ÜST ÇUBUK BAŞLIĞI (15 Kasım, yönetici notu): yazı yerine logo + "Yüküm" (Design/YukumLogo › BrandTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { BrandTitle() } }
            .toolbar { // .toolbar [SWIFT]: üst çubuğa eleman koyar
                // Zil: iki rolde de görünür | NavigationLink [SWIFT]: basınca ekranı bu yığına iter (Geri kendiliğinden gelir) ⮕ Views/NotificationsView
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { NotificationsView() } label: {
                        Image(systemName: "bell") // SF Symbols: zil
                            // ROZET YERLEŞİMİ (13 Kasım düzeltmesi): önceden rozet .offset ile zilin DIŞINA itiliyordu.
                            // .offset [SWIFT] yalnız çizimi kaydırır, kapladığı yeri büyütmez → üst çubuk rozeti "yok" sayıp + düğmesini hemen yanına koyuyordu, sayı + ile üst üste biniyordu.
                            // Şimdi önce zilin çevresine yer açılır (.frame), rozet o alanın İÇİNDE sağ üst köşeye oturur → çubuk bu genişliği bilir, + düğmesini öteye koyar.
                            .frame(width: 40, height: 34) // .frame [SWIFT]: kapladığı alan | zil ortada kalır, köşede rozete yer açılır
                            .overlay(alignment: .topTrailing) { // .overlay [SWIFT]: bu alanın sağ üstüne rozet çizer
                                if viewModel.unreadNotifications > 0 { // 0 ise rozet yok | ⮕ HomeViewModel.unreadNotifications ← NotificationService.unreadCount()
                                    // 99'dan büyükse "99+": rozet sınırsız genişleyip yine taşmasın
                                    Text(viewModel.unreadNotifications > 99 ? "99+" : "\(viewModel.unreadNotifications)")
                                        .font(.caption2).fontWeight(.bold).foregroundColor(.white)
                                        .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18) // minWidth = minHeight: tek hanede tam daire
                                        .background(Color.red).clipShape(Capsule()) // Capsule [SWIFT]: uçları yuvarlak şekil; iki-üç hanede yana uzar, daire gibi kırpmaz
                                }
                            }
                    }
                }
                // GÖRÜNÜM DÜĞMESİ (Sistem / Açık / Koyu): iki rolde de sol üstte | ⮕ Design/ThemeToggle.swift (giriş ekranındakiyle aynı ayar)
                ToolbarItem(placement: .topBarLeading) { ThemeToggle() }
                // PROFİL (15 Kasım, 8. adım): sol üstte kendi fotoğrafın → Views/ProfileView
                //   Eski Teklifler (saat), Favoriler (kalp), Tekliflerim (kutu) simgeleri profile taşındı → üst çubuk sade: profil · tema | logo | zil
                //   Görülmemiş teklif kararı varsa fotoğrafın köşesinde turuncu nokta (sayı profilde "Tekliflerim" satırında)
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ProfileView(isShipper: viewModel.isShipper, name: viewModel.user.displayName, me: viewModel.me,
                                    unseenCount: viewModel.unseenCount, activeJobCount: viewModel.activeJobCount,
                                    onRename: { name in viewModel.renameUser(name) },   // ⮕ HomeViewModel.renameUser (selamlama + profil başlığı)
                                    onRefresh: { await viewModel.loadMe(); await viewModel.loadActiveJobCount() }, // profil her göründüğünde fotoğraf/puan + devam eden iş sayısı tazelenir
                                    onSignOut: { await viewModel.signOut(); dismiss() }, // ⮕ AuthSession.signOut → giriş ekranı
                                    onDeleted: { dismiss() })                            // hesap silindi → giriş ekranı (yerel oturum zaten silindi)
                    } label: {
                        AvatarView(url: viewModel.me?.avatarUrl, name: viewModel.user.displayName, size: 32) // ⮕ Design/AvatarView.swift
                            .overlay(alignment: .topTrailing) {
                                if viewModel.unseenCount > 0 { Circle().fill(Color.orange).frame(width: 10, height: 10).offset(x: 2, y: -2) }
                            }
                            .accessibilityLabel(viewModel.unseenCount > 0 ? "Profil, yeni teklif kararı var" : "Profil")
                    }
                }
            }
            // .task(id:) [SWIFT]: ekran HER göründüğünde çalışır (ilk açılış + başka ekrandan geri dönünce) + id DEĞİŞİNCE de yeniden çalışır
            // NE İŞE YARAR: il/ilçe Picker'ı, "Yakınımdakiler" anahtarı ya da konum değişince liste kendiliğinden yeniden çekilir, ayrı "Ara" düğmesi gerekmez | teklif verip/karar verip dönünce de liste ve rozet yenilenir
            // id: ViewModel.reloadKey → filtre + anahtar + konumu birleştiren yazı | bu yazı değişince blok yeniden çalışır
            // Push: giriş yapılmış ekran açılınca izin + kayıt ⮕ HomeViewModel.enablePush() → PushManager.enable()
            .task { await viewModel.enablePush() }
            // SOĞUK AÇILIŞ: uygulama kapalıyken bildirime basıldıysa anons bu ekran kurulmadan önce yapılmıştır (kaçtı); bekleyen notu burada okuruz
            // ⮕ PushManager.takePendingTap() (neden gerektiği orada yazılı)
            .task { if PushManager.shared.takePendingTap() { showNotifications = true } }
            // NEDEN ANONS (NotificationCenter): AppDelegate bir View değil, HomeView'ın @State'ine ulaşamaz → olayı anons eder, dinleyen ekran kendi durumunu değiştirir (sessionExpired ile aynı kalıp)
            // Telefondaki bildirime dokunuldu (App/AppDelegate yayınlar) → liste açılır | .navigationDestination(isPresented:) [SWIFT]: Bool true olunca ekranı yığına iter
            .onReceive(NotificationCenter.default.publisher(for: .pushTapped)) { _ in
                if PushManager.shared.takePendingTap() { showNotifications = true } // notu da al: yoksa bir sonraki açılışta liste bir kez daha açılırdı
            }
            .navigationDestination(isPresented: $showNotifications) { NotificationsView() }
            // Uygulama açıkken bildirim geldi → zil sayısını tazele
            .onReceive(NotificationCenter.default.publisher(for: .pushReceived)) { _ in Task { await viewModel.loadUnread() } }
            // .onAppear [SWIFT]: ekran HER göründüğünde çalışır (bildirim listesinden Geri ile dönünce de) → rozet güncel kalır
            .onAppear { Task { await viewModel.loadUnread(); await viewModel.loadMe() } } // loadMe (15 Kasım): profil fotoğrafı / ad tazelenir
            .task(id: viewModel.reloadKey) { // ⮕ HomeViewModel.reloadKey: bu yazı değişince load() yeniden çalışır
                await viewModel.load() // asıl iş ViewModel'de | aynı işi hem .task hem .refreshable çağırıyor, kod tekrarlanmasın | ⮕ HomeViewModel.load(coordinate:) → ilgili Service → APIClient → API
                listLoaded = true // ilk yükleme bitti → boş liste artık gerçekten boş demek
            }
        }
    }
}

// ─── YÜK VEREN ANA EKRANI (L tasarım, 13 Kasım) ───────────────────────────────
// NEDEN extension + ayrı özellik: body zaten uzun; Yük Veren tasarımı tek yerde okunsun. Yeni dosya açılmadı (klasör yapısı sabit).
// ZİNCİR: body → if isShipper → shipperHome → ScrollView: selamlama → "Yeni ilan ver" → yarı şeffaf ilan kartları | TÜM EKRANIN arkasında: shipperBackground → TruckLoadView(progress: 1)
// NE DEĞİŞMEDİ: liste verisi (viewModel.listings), ListingRow, satıra basınca ListingOffersView, üst çubuk (+, geçmiş, zil), Taşımacı dalı.
// NEDEN List yerine ScrollView + LazyVStack: List kendi beyaz zeminini ve ayırıcı çizgilerini çizer, kart görünümü vermez.
//   LazyVStack [SWIFT]: yalnız ekrana giren satırları kurar → çok ilan olsa da hızlı | .refreshable ScrollView'da da çalışır.
extension HomeView {

    // ⮕ KULLANIM [shipperHome]: kullanır: HomeView › body (isShipper dalı)
    var shipperHome: some View {
        let palette = Palette(isDark: colorScheme == .dark)

        return ScrollView { // ScrollView [SWIFT]: içeriği kaydırılabilir yapar
            VStack(alignment: .leading, spacing: 18) {

                // 1) SELAMLAMA: giriş ekranıyla aynı renkler (palette.title / label)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Merhaba, \(viewModel.user.displayName)").font(.title.bold()).foregroundStyle(palette.title) // ⮕ LoginUser.displayName
                    Text("Yükün yolda, aklın rahat.").font(.subheadline).foregroundStyle(palette.label.opacity(0.75))
                }

                // (15 Kasım, kullanıcı: "kalacak animasyonlar: ilan verince kutu paketleme, silmedeki gibi basit animasyonlar; profesyonel olsun")
                //   Ana ekrandaki 3B dorse sahnesi KALDIRILDI → sade ekran: selamlama, ana düğme, ilanlar. İşlem animasyonları: Design/ActionFeedback.

                // 2) ANA EYLEM: üst çubuktaki + ile aynı yere gider; büyük düğme ilk ilanı verecek kişiye yolu gösterir
                NavigationLink { CreateListingView() } label: { // ⮕ Views/CreateListingView.swift
                    Label("Yeni ilan ver", systemImage: "plus.circle.fill") // Label [SWIFT]: simge + yazı
                        .font(.headline)
                        .foregroundStyle(palette.buttonText)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(palette.accent, in: .rect(cornerRadius: 14)) // LoginView'daki "Giriş yap" ile aynı düğme
                }

                if let listError = viewModel.listError { FormMessage(text: listError, isError: true) } // doluysa uyarı simgeli yazı (Design/FormStyle), nil ise çizilmez

                // 3) İLANLAR: başlıkta sayı | ⮕ HomeViewModel.listings ← load() ← ListingService.myListings() → GET /api/v1/listings/mine
                Text("İlanların (\(viewModel.listings.count))").font(.title3.bold()).foregroundStyle(palette.title)

                if viewModel.listings.isEmpty && !listLoaded {
                    LoadingCard() // ⮕ Design/FormStyle.swift
                } else if viewModel.listings.isEmpty {
                    Text("Henüz ilanın yok, ilk ilanını ver.").foregroundStyle(palette.label.opacity(0.7))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.listings) { listing in
                            NavigationLink { ListingOffersView(listing: listing) } label: { // ⮕ Views/ListingOffersView.swift (değişmedi)
                                HStack {
                                    ListingRow(listing: listing) // ⮕ Views/ListingRow.swift (değişmedi)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(palette.accent) // List'teki ok burada kendiliğinden gelmez
                                }
                                .foregroundStyle(palette.title) // ListingRow'un ana yazıları palete uysun (.secondary gri yazılar kendi rengini korur)
                                .padding(14)
                                .background(palette.cardSurface.opacity(0.88), in: .rect(cornerRadius: 16)) // 15 Kasım: 0,55 → 0,88 (okunurluk; arkada sahne yok) | eski not: YARI ŞEFFAF (14 Kasım): kaydırınca arkadaki dorse kartların içinden görünür | koyu modda koyu, açıkta krem
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(palette.cardBorder))
                            }
                            .buttonStyle(.plain) // [SWIFT] NavigationLink yazıyı maviye boyamasın
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.load() } // aşağı çekince yenile (eski List'teki ile aynı iş)
    }

    // BU GÖRÜNÜM: Yük Veren ekranının TAM EKRAN arka planı: renk geçişi + ışık haleleri (HAREKETSİZ).
    //   15 Kasım: 3B dorse önce kartların arkasından çerçeveye taşındı, sonra tamamen kaldırıldı (kullanıcı: profesyonel, sade).
    // BAĞLANTI: body'deki .background { if isShipper { shipperBackground } } çağırır | renkler Design/DesignPalette.swift
    // ⮕ KULLANIM [shipperBackground]: kullanır: HomeView › body (.background)
    var shipperBackground: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        return ZStack {
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
            // Işık haleleri: dorsenin arkasında bulanık amber bulutlar (giriş ekranıyla aynı, ucuz 2B katman) → sahne daha aydınlık
            SoftGlow(color: palette.glowA, width: 380, height: 320).offset(x: -120, y: -40)
            SoftGlow(color: palette.glowB, width: 360, height: 300).offset(x: 130, y: 120)
        }
        .ignoresSafeArea() // [SWIFT] çentik ve alt çubuk dahil tüm ekran
        .allowsHitTesting(false) // [SWIFT] arka plan dokunuş almaz → dokunuşlar üstteki düğme ve kartlara gider
    }
}

// ─── TAŞIMACI ANA EKRANI (L tasarım, 14 Kasım: yol + yük teslim alma teması) ──────────────────
// NEDEN extension: Yük Veren ile aynı kalıp (shipperHome); body kısa kalsın, Taşımacı tasarımı tek yerde okunsun. Yeni Views dosyası açılmadı.
// ZİNCİR: body → else (Carrier) → carrierHome → ScrollView: selamlama → "Yük ara" paneli → tabela başlık → rota kartları (LazyVStack, sayfalı)
//         TÜM EKRANIN arkasında: carrierBackground → Design/TruckRoadView (yol + yükleme alanı; dorse yanaşır, yük alınır, sahne durur)
// NE DEĞİŞMEDİ (işlev): il/ilçe Picker'ları + .onChange → cityFilterChanged | Yakınımdakiler + nearMeChanged | Filtre sayfası (showFilter) |
//   son satır görününce loadMore | aşağı çekince load | satıra basınca ListingDetailView | HomeViewModel'e dokunulmadı.
// NE DEĞİŞTİ (görünüm): List → yarı şeffaf kartlar (shipperHome'daki gibi) | ListingRow yerine rota kartı (RouteCard, Views/ListingRow.swift): Nereden ——🚚—— Nereye.
//   ListingRow değişmedi (Yük Veren ve diğer ekranlar onu kullanmaya devam ediyor).
extension HomeView {

    // ⮕ KULLANIM [carrierHome]: kullanır: HomeView › body (else = Carrier dalı)
    var carrierHome: some View {
        let palette = Palette(isDark: colorScheme == .dark)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // 1) SELAMLAMA: Yük Veren ile aynı ölçü ve renkler, Taşımacı'ya göre söz
                VStack(alignment: .leading, spacing: 4) {
                    Text("İyi yolculuklar, \(viewModel.user.displayName)").font(.title.bold()).foregroundStyle(palette.title) // ⮕ LoginUser.displayName
                    Text("Yük hazır, yol senin.").font(.subheadline).foregroundStyle(palette.label.opacity(0.75))
                }

                // (15 Kasım) Ana ekrandaki 3B yük teslim alma sahnesi KALDIRILDI (kullanıcı: "profesyonel, sade"); işlem animasyonları kalır.

                // 2) YÜK ARA PANELİ: eski ekrandaki tüm filtre öğeleri tek kartta
                carrierSearchPanel(palette: palette)

                if let listError = viewModel.listError { FormMessage(text: listError, isError: true) } // doluysa uyarı yazısı (Yük Veren ile aynı değişken)

                // 2b) SONUÇ + SIRALA + ETKİN FİLTRELER (15 Kasım, sahibinden tarzı) ⮕ aşağıdaki carrierResultsBar
                carrierResultsBar(palette: palette)

                // 3) BAŞLIK: turuncu yol tabelası (yol çalışması tabelaları turuncudur → marka rengiyle aynı) | içte ince çerçeve: gerçek tabela kenarı
                HStack(spacing: 8) {
                    Image(systemName: "road.lanes")
                    Text("AÇIK İLANLAR").font(.subheadline.weight(.heavy)).tracking(1.4) // .tracking [SWIFT]: harf aralığı (tabela yazısı gibi)
                }
                .foregroundStyle(palette.buttonText)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(palette.accent, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(palette.buttonText.opacity(0.8), lineWidth: 1.5).padding(3))

                // 4) İLANLAR | ⮕ HomeViewModel.listings ← load()/loadMore() ← ListingService.openListings() → GET /api/v1/listings?...
                if viewModel.listings.isEmpty && !listLoaded {
                    LoadingCard(text: "İlanlar yükleniyor…")
                } else if viewModel.listings.isEmpty {
                    VStack(spacing: 8) { // boş durum: yol simgesi + yönlendirme (filtre yüzünden boşsa geri alınabilsin diye panel yukarıda kalır)
                        Image(systemName: "road.lanes").font(.largeTitle).foregroundStyle(palette.accent.opacity(0.85))
                        // 15 Kasım: boşluğun SEBEBİ söylenir (filtre mi, gerçekten ilan yok mu) + tek dokunuşla geri alma
                        Text(viewModel.filter.matchMyVehicles ? "Araçlarına uygun açık ilan yok." : viewModel.filterChips.isEmpty ? "Şu an açık ilan yok." : "Filtrene uyan ilan yok.")
                            .font(.headline).foregroundStyle(palette.title)
                        Text(viewModel.filterChips.isEmpty ? "Biraz sonra tekrar bak." : "Filtreleri gevşetirsen daha çok ilan görürsün.").font(.caption).foregroundStyle(palette.label.opacity(0.7))
                        if !viewModel.filterChips.isEmpty {
                            Button(viewModel.filter.matchMyVehicles && viewModel.filterChips.count == 1 ? "Araç filtresini kaldır" : "Filtreleri temizle") { viewModel.clearFilters() }
                                .buttonStyle(ChipButtonStyle(.accent))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                    .background(palette.cardSurface.opacity(0.55), in: .rect(cornerRadius: 16))
                } else {
                    LazyVStack(spacing: 10) { // LazyVStack [SWIFT]: yalnız ekrana giren kartları kurar → sayfalı uzun listede hızlı
                        ForEach(viewModel.listings) { listing in
                            NavigationLink { ListingDetailView(listing: listing) } label: { // ⮕ Views/ListingDetailView.swift (değişmedi)
                                RouteCard(listing: listing) // ⮕ Views/ListingRow.swift › RouteCard (15 Kasım: Favoriler ve İlan Detayı da kullanıyor)
                            }
                            .buttonStyle(.plain) // [SWIFT] NavigationLink yazıyı maviye boyamasın
                            .onAppear { // son kart ekrana girince sonraki sayfa (eski List'teki ile aynı mantık)
                                if listing.id == viewModel.listings.last?.id {
                                    Task { await viewModel.loadMore() } // ⮕ HomeViewModel.loadMore(): GET ...?page=2
                                }
                            }
                        }
                        if viewModel.isLoadingMore { // ⮕ HomeViewModel.isLoadingMore
                            ProgressView().tint(palette.accent).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.load() } // aşağı çekince yenile
    }

    // BU GÖRÜNÜM: "Yük ara" paneli. Eski Taşımacı ekranındaki il/ilçe Picker'ları, Yakınımdakiler anahtarı, konum mesajları ve Filtre düğmesi
    //   AYNI bağlarla (aynı $viewModel alanları, aynı .onChange'ler) burada. Yalnız görünüm değişti.
    // NEDEN ayrı fonksiyon: carrierHome tek parça olunca Swift'in tür denetimi yavaşlıyor; ayrıca $ bağları için @Bindable gerekiyor.
    // ⮕ KULLANIM [carrierSearchPanel]: kullanır: carrierHome
    func carrierSearchPanel(palette: Palette) -> some View {
        @Bindable var viewModel = viewModel // [SWIFT] @Bindable: $viewModel.alan ile iki yönlü bağ (Picker/Toggle seçimi doğrudan ViewModel'e yazılır)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nereden yük alacaksın?", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.bold()).foregroundStyle(palette.title)
                Spacer()
                Button { showFilter = true } label: { // alttan Filtre sayfası (.sheet body'de)
                    Label(viewModel.filter.extraCount > 0 ? "Filtre (\(viewModel.filter.extraCount))" : "Filtre", systemImage: "slider.horizontal.3") // sayfadaki aktif filtre sayısı
                        .font(.footnote.bold()).foregroundStyle(palette.buttonText)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(palette.accent, in: .capsule)
                }
            }

            // KALKIŞ İLİ + İLÇESİ (eskisiyle aynı bağ ve tetikleme) | .tint: menüdeki seçili yazının rengi
            HStack(spacing: 8) {
                Picker("İl", selection: $viewModel.filter.fromCityId) { // ⮕ HomeViewModel.filter.fromCityId
                    Text("Tüm İller").tag(0) // 0 = filtre yok
                    ForEach(viewModel.cities) { city in Text(city.name).tag(city.id) } // ⮕ HomeViewModel.cities ← CityService.cities()
                }
                .pickerStyle(.menu).tint(palette.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.fieldSurface, in: .rect(cornerRadius: 10))
                .onChange(of: viewModel.filter.fromCityId) { _, newId in // il değişince ilçe sıfırlanır + yeni ilçeler çekilir (mantık ViewModel'de)
                    Task { await viewModel.cityFilterChanged(to: newId) } // ⮕ HomeViewModel.cityFilterChanged → CityService.districts(cityId:)
                }
                if viewModel.filter.fromCityId != 0 { // il seçilmeden ilçe çizilmez
                    Picker("İlçe", selection: $viewModel.filter.fromDistrictId) {
                        Text("Tüm İlçeler").tag(0)
                        ForEach(viewModel.filterDistricts) { district in Text(district.name).tag(district.id) }
                    }
                    .pickerStyle(.menu).tint(palette.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.fieldSurface, in: .rect(cornerRadius: 10))
                }
            }

            // YAKINIMDAKİLER: aç → nearMe = true → .onChange → konum izni/konum → .task(id: reloadKey) listeyi yeniler → kartlarda "12 km"
            Toggle(isOn: $viewModel.nearMe) {
                Label("Yakınımdakiler", systemImage: "location.fill").font(.subheadline).foregroundStyle(palette.label)
            }
            .tint(palette.accent) // [SWIFT] açıkken anahtarın rengi
            .onChange(of: viewModel.nearMe) { _, on in
                viewModel.nearMeChanged(to: on) // ⮕ HomeViewModel.nearMeChanged → Models/Location/LocationManager.request()
            }

            // izin/konum mesajları (eskisiyle aynı koşullar)
            if viewModel.isLocationDenied {
                HStack {
                    Text("Konum izni kapalı").font(.caption).foregroundColor(.red)
                    Button("Ayarları aç") { openURL(URL(string: UIApplication.openSettingsURLString)!) }.font(.caption.bold()).tint(palette.accent)
                }
            } else if let message = viewModel.locationError {
                Text(message).font(.caption).foregroundColor(.red)
            }
        }
        .padding(14)
        .background(palette.cardSurface.opacity(0.88), in: .rect(cornerRadius: 18)) // 15 Kasım: 0,62 → 0,88 (okunurluk; arkada sahne yok)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(palette.cardBorder))
    }

    // BU GÖRÜNÜM (15 Kasım, sahibinden tarzı): "128 ilan" + Sırala menüsü + etkin filtre kapsülleri (dokun → kaldır) + Tümünü temizle
    //   Sıralama filtreden AYRI (sahibinden'deki gibi): Menu → filter.sort → reloadKey → load() | kapsüller: HomeViewModel.filterChips / removeChip
    // ⮕ KULLANIM [carrierResultsBar]: carrierHome
    func carrierResultsBar(palette: Palette) -> some View {
        @Bindable var viewModel = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(listLoaded ? "\(viewModel.totalCount.formatted()) ilan" : " ").font(.subheadline.bold()).foregroundStyle(palette.title)
                Spacer()
                Menu {
                    Picker("Sırala", selection: $viewModel.filter.sort) {
                        Text(viewModel.nearMe ? "En yakın (varsayılan)" : "En yeni (varsayılan)").tag(ListingSort?.none)
                        ForEach(ListingSort.allCases) { Text($0.title).tag(ListingSort?.some($0)) }
                    }
                } label: {
                    Label(viewModel.filter.sort?.title ?? "Sırala", systemImage: "arrow.up.arrow.down").font(.footnote.bold())
                }
                .buttonStyle(ChipButtonStyle(.outline))
            }
            if !viewModel.filterChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { // ScrollView(.horizontal) [SWIFT]: sığmayan kapsüller yana kayar
                    HStack(spacing: 6) {
                        ForEach(viewModel.filterChips) { chip in
                            Button { viewModel.removeChip(chip.id) } label: { Label(chip.title, systemImage: "xmark").labelStyle(TrailingIconLabelStyle()) }
                                .buttonStyle(ChipButtonStyle(.accent))
                        }
                        Button("Tümünü temizle") { viewModel.clearFilters() }.buttonStyle(ChipButtonStyle(.outline))
                    }
                }
            }
        }
    }

    // BU GÖRÜNÜM: Taşımacı ekranının TAM EKRAN arka planı: renk geçişi + haleler (HAREKETSİZ).
    //   15 Kasım: 3B yük teslim alma sahnesi kaldırıldı (kullanıcı: profesyonel, sade).
    // ⮕ KULLANIM [carrierBackground]: kullanır: HomeView › body (.background)
    var carrierBackground: some View {
        ScreenBackground() // ⮕ Design/ActionFeedback.swift
    }
}

// Kapsülde yazı önce, ✕ sonra ("50 km ✕") | LabelStyle [SWIFT]: Label'ın simge/yazı yerleşimini özelleştirir
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon.imageScale(.small) }
    }
}
