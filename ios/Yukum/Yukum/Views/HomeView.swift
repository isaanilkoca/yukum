//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: HomeView (ana sayfa, iki rol) ─────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Yük Veren tasarımı       →  shipperHome + shipperBackground (bu dosyanın sonunda): selamlama, arkada tam ekran Design/TruckLoadView (3B dorse), "Yeni ilan ver", ilan kartları | renkler: Design/DesignPalette.swift
// │ Hoş Geldin yazısı        →  viewModel.user                     →  (servis yok)                    →  (LoginView'dan gelir)            →  LoginUser
// │ Yük Veren ilan listesi   →  viewModel.listings ← load()         →  ListingService.myListings()     →  GET /api/v1/listings/mine        →  [Listing]
// │ Taşımacı ilan listesi    →  viewModel.listings ← load()         →  ListingService.openListings()   →  GET /api/v1/listings?...         →  [Listing]
// │ İl / İlçe Picker'ları    →  cities, filterDistricts, filterCityId, filterDistrictId  →  CityService.cities() / districts()  →  GET /cities, /cities/{id}/districts  →  [City] / [District]
// │ Yakınımdakiler anahtarı  →  viewModel.nearMe, nearMeChanged(to:) (konum izni/konumu ViewModel'in Location sözleşmesinden)  →  load() → ListingService.openListings(lat,lon)  →  GET ...?lat=&lon=  →  Listing.distanceKm
// │ Kutu ikonundaki rozet    →  viewModel.unseenCount ← load()     →  OfferService.unseenCount()      →  GET /api/v1/offers/mine/unseen-count  →  UnseenCount
// │ Çıkış Yap                →  viewModel.signOut()                 →  AuthSession.signOut()           →  POST /api/v1/auth/logout         →  (yok)
// │ Oturum bitti uyarısı     →  NotificationCenter .sessionExpired  →  AuthSession yayınlar            →  -                                →  dismiss() ile giriş ekranına
// │ Satıra dokunma / ikonlar →  Yük Veren: ListingOffersView(listing:) | Taşımacı: ListingDetailView(listing:) | "Yeni ilan ver" → CreateListingView (tek yol, + kaldırıldı), OldOffersView, MyOffersView
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
    
    @State private var showDeleteAccount = false // "Hesabı Sil" sayfası açık mı | true → .sheet görünür
    
    @State private var showPrivacy = false // "Gizlilik ve KVKK" sayfası açık mı | true → .sheet görünür
    
    @State private var showNotifications = false // true → bildirim listesi açılır (telefondaki bildirime dokununca)
    @State private var showFilter = false // Filtre sayfası açık mı | true → .sheet görünür
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
                    Text("Hoş Geldin \(viewModel.user.displayName)").font(.title2).bold() // \( ) = yazının içine değişken koyar | LoginUser'daki ad alanı | ⮕ viewModel.user ← LoginViewModel.loggedInUser (LoginUser) | NEDEN else içinde: Yük Veren'in selamlaması artık shipperHome'da
                    if let listError = viewModel.listError { Text(listError).foregroundColor(.red) } // hata varsa kırmızı yaz (Yük Veren ile aynı değişken)

                    HStack { // başlık solda, Filtre düğmesi sağda
                        Text("Açık İlanlar").font(.title3).bold() // liste başlığı | boş olsa da görünsün diye if listings.isEmpty'nin DIŞINDA
                        Spacer()
                        Button { showFilter = true } label: { // basınca alttan Filtre sayfası açılır (.sheet aşağıda)
                            Label(viewModel.filter.extraCount > 0 ? "Filtre (\(viewModel.filter.extraCount))" : "Filtre", systemImage: "line.3.horizontal.decrease.circle") // sayfadaki aktif filtre sayısı
                        }
                    }

                    // ─── FİLTRE: kalkış ili + ilçesi | NEDEN if listings.isEmpty'nin ÜSTÜNDE: filtre sonucu boş çıkarsa Picker'lar da kaybolmasın, kullanıcı filtreyi geri alabilsin ───
                    HStack { // HStack [SWIFT]: yan yana dizer | il ve ilçe Picker'ları yan yana
                        Picker("İl", selection: $viewModel.filter.fromCityId) { // Picker [SWIFT]: açılır liste | selection: seçilen değer ViewModel'deki filterCityId'ye yazılır ($ = iki yönlü bağ) | ⮕ HomeViewModel.filterCityId (Picker seçimi buraya yazılır)
                            Text("Tüm İller").tag(0) // tag(0): "Tümü" seçeneği, değeri 0 = filtre yok | .tag [SWIFT]: Picker seçeneğinin değeri
                            ForEach(viewModel.cities) { city in // ForEach [SWIFT]: listedeki her il için bir satır çizer | cities: ViewModel.load'da dolan liste | ⮕ HomeViewModel.cities ← CityService.cities() → [City]
                                Text(city.name).tag(city.id) // city.name: ekranda görünen ad | tag(city.id): seçilince değişkene yazılacak numara
                            }
                        }
                        .pickerStyle(.menu) // açılır menü görünümü | .pickerStyle [SWIFT]: seçici görünüm stili
                        // .onChange [SWIFT]: değişkeni izler, değişince BİR KEZ çalışır | il değişince ViewModel ilçe seçimini sıfırlar ve yeni ilin ilçelerini çeker (mantık ViewModel'de, burada yalnız tetikleme)
                        .onChange(of: viewModel.filter.fromCityId) { _, newId in // _ = eski değer (kullanmıyoruz) | newId = yeni değer
                            Task { await viewModel.cityFilterChanged(to: newId) } // Task [SWIFT]: .onChange bekleyemez, internet isteği await ister; await yalnız Task içinde yazılır | ⮕ HomeViewModel.cityFilterChanged → CityService.districts(cityId:) → filterDistricts
                        }
                        if viewModel.filter.fromCityId != 0 { // il seçilmeden ilçe Picker'ı çizilmez
                            Picker("İlçe", selection: $viewModel.filter.fromDistrictId) { // seçilen ilçe numarası ViewModel'e yazılır
                                Text("Tüm İlçeler").tag(0) // 0 = ilçe filtresi yok
                                ForEach(viewModel.filterDistricts) { district in // ViewModel.cityFilterChanged'in doldurduğu liste
                                    Text(district.name).tag(district.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Anahtarı aç → nearMe = true → .onChange → request() → izin penceresi → konum bulunur → coordinate dolar
                    // → .task(id:) bunu fark edip yeniden çalışır → ViewModel.load(coordinate:) → sunucu sıralar → "12 km" görünür

                    // ─── YAKINIMDAKİLER: telefonun konumuna göre en yakından uzağa sırala ───
                    // Toggle [SWIFT]: aç/kapa anahtarı | isOn: $viewModel.nearMe → açınca nearMe true olur
                    Toggle("Yakınımdakiler", isOn: $viewModel.nearMe) // ⮕ HomeViewModel.nearMe → true ise load() konumu API'ye (lat/lon) gönderir
                        // .onChange: nearMe değişince BİR KEZ çalışır | on: yeni değer
                        // açıldıysa konum motoruna "izin sor ve konumu bul" deriz (izin ya da konum gelene kadar liste eskisi gibi kalır, gelince .task(id:) listeyi yeniler)
                        .onChange(of: viewModel.nearMe) { _, on in
                            viewModel.nearMeChanged(to: on) // konum isteme kararı ViewModel'de | ⮕ HomeViewModel.nearMeChanged → Models/Location/LocationManager.request()
                        } // NOT: ekrana bir şey ÇİZEN kod (Text, HStack) .onChange'in içine yazılmaz, çünkü orası "olunca çalışacak iş" bloğu, çizim bloğu değil | mesajlar aşağıda, dışarıda

                    // izin/konum mesajları: viewModel.isLocationDenied ve locationError (kaynak Models/Location/LocationManager, @Observable) değişince bu bloklar kendiliğinden yeniden değerlendirilir
                    if viewModel.isLocationDenied { // izin reddedilmişse (kodla tekrar sorulamaz, yalnız Ayarlar'dan açılır)
                        HStack {
                            Text("Konum izni kapalı").font(.caption).foregroundColor(.red)
                            // Button: basınca iOS Ayarlar uygulamasında bu uygulamanın sayfasını açar | UIApplication.openSettingsURLString: Apple'ın hazır "ayarlar" adresi
                            Button("Ayarları aç") { openURL(URL(string: UIApplication.openSettingsURLString)!) }.font(.caption) // UIApplication [SWIFT]: iOS uygulama nesnesi (Ayarlar adresi için)
                        }
                    } else if let message = viewModel.locationError { // else if: ya da | konum alınamadıysa (GPS yok vb.) hata yazısı
                        Text(message).font(.caption).foregroundColor(.red)
                    }

                    if viewModel.listings.isEmpty { // liste boş mu
                        Text("Şuan açılmış bir ilan yok.").foregroundColor(.secondary) // boşsa bu yazı görünür
                    } else {
                        List { // List [SWIFT]: bu kez içine ForEach + ek satır koyacağımız biçim
                                                   ForEach(viewModel.listings) { listing in // ForEach [SWIFT]: her ilan için bir satır | ⮕ HomeViewModel.listings ← load()/loadMore()
                                                       NavigationLink { // NavigationLink [SWIFT]: satıra basınca süslü parantezdeki ekrana geçer
                                                           ListingDetailView(listing: listing) // Views/ListingDetailView.swift → basılan ilanı detay ekranına VERİYORUZ
                                                       } label: { // label: satırın görünen kısmı
                                                           ListingRow(listing: listing) // Views/ListingRow.swift
                                                       }
                                                       .onAppear { // .onAppear [SWIFT]: bu satır ekrana GİRİNCE çalışır
                                                           if listing.id == viewModel.listings.last?.id { // son satır mı | ?. : liste boşsa nil
                                                               Task { await viewModel.loadMore() } // Task [SWIFT]: async işi başlatır | ⮕ HomeViewModel.loadMore(): sonraki sayfa → GET ...?page=2
                                                           }
                                                       }
                                                   }
                                                   if viewModel.isLoadingMore { // ⮕ HomeViewModel.isLoadingMore: sayfa yüklenirken true
                                                       ProgressView().frame(maxWidth: .infinity) // ProgressView [SWIFT]: dönen çark | listenin altında ortalı
                                                   }
                                               }
                        .refreshable { await viewModel.load() } // aşağı çekince yenile
                    }
                }
                
                // Hesabı Sil: ayrı sayfa açar (şifre onayı orada) | role: .destructive [SWIFT]: kırmızı tehlikeli işlem düğmesi
                // .buttonStyle(.borderedProminent) [SWIFT]: içi dolu düğme (Çıkış Yap ile aynı) | .tint(.red) [SWIFT]: dolgu rengini kırmızı yapar
                
                
                // Gizlilik ve KVKK: sabit metin sayfası açar | .sheet aynı düğmeye bağlı (modifier her görünüme eklenebilir)
                                Button("Gizlilik ve KVKK") { showPrivacy = true }.font(.footnote)
                                    .sheet(isPresented: $showPrivacy) { PrivacyView() } // ⮕ Views/PrivacyView
                
                Button("Hesabı Sil", role: .destructive) { showDeleteAccount = true }.buttonStyle(.borderedProminent).tint(.red) // ⮕ aşağıdaki .sheet → Views/DeleteAccountView

                Button("Çıkış Yap") { // Button [SWIFT]: tıklanınca süslü parantezdeki kod çalışır
                    // ÇIKIŞ: önce yerel oturum silinir (Keychain + bellek), sonra sunucuya haber verilir (jeton orada da iptal edilsin) | BAĞLANTI: Models/Networking/AuthSession.swift → signOut
                    Task { // Task [SWIFT]: düğmede await kullanmamızı sağlar
                        await viewModel.signOut() // ⮕ HomeViewModel.signOut() → Models/Networking/AuthSession.signOut() → Keychain silinir + POST /api/v1/auth/logout
                        dismiss() // bu ekranı kapatır → LoginView'daki loggedInUser nil olur → giriş ekranına dönülür
                    }
                }.buttonStyle(.borderedProminent) // .buttonStyle [SWIFT]: düğme görünüm stili

            }.padding() // .padding [SWIFT]: etrafında boşluk bırakır
            // Yük Veren'de arka plan giriş ekranının renk geçişi (aynı palet) | Taşımacı ekranı henüz tasarlanmadı → sistem zemini kalır
            .background { if viewModel.isShipper { shipperBackground } } // ⮕ aşağıdaki extension HomeView › shipperBackground (renk geçişi + 3B dorse)
            // .onReceive [SWIFT]: bir "yayını" dinler | oturum yenilenemezse (süre doldu, jeton iptal edildi/çalıntı sanıldı) AuthSession "sessionExpired" yayınlar
            // → ekran kapanır ve kullanıcı giriş ekranına döner (jeton zaten silindi) | NEDEN gerekli: arka plandaki istekler 401 alıp yenileyemediğinde kullanıcı boşta kalmasın
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in dismiss() } // ⮕ yayıncı: AuthSession.expireSession() (Models/Networking/Notification+SessionExpired.swift) | NotificationCenter [SWIFT]: uygulama içi anons panosu (biri yayınlar, ilgilenen dinler)
            
            // Hesap silme sayfası: başarılı olunca onDeleted çalışır → dismiss() bu ekranı kapatır → LoginView'daki loggedInUser nil olur → giriş ekranı (yerel oturum zaten silindi)
            .sheet(isPresented: $showDeleteAccount) { DeleteAccountView(onDeleted: { dismiss() }) } // .sheet [SWIFT]: alttan açılan sayfa

            .sheet(isPresented: $showFilter) { // .sheet [SWIFT]: alttan açılan sayfa | showFilter true olunca görünür
                OpenListingsFilterView(filter: viewModel.filter, cities: viewModel.cities) { viewModel.filter = $0 } // Uygula → ViewModel.filter → reloadKey → load()
            }
            .navigationTitle("Yüküm") // [SWIFT] üst çubuktaki başlık | .navigationTitle [SWIFT]: üst çubuk başlığı
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
                if viewModel.isShipper { // yalnız Yük Veren ilan açabilir
                    // (14 Kasım) Sağ üstteki + düğmesi KALDIRILDI: ilan vermenin iki yolu vardı (+ ve "Yeni ilan ver"); kullanıcı tek yol istedi.
                    //   İlan artık yalnız ana ekrandaki turuncu "Yeni ilan ver" düğmesinden verilir (shipperHome).
                    ToolbarItem(placement: .topBarLeading) { // GÖRÜNÜM kararı: "Eski teklifler" yalnız Yük Veren'de çıkar | .topBarLeading: sol üst köşe
                        NavigationLink {
                            OldOffersView() // Views/OldOffersView.swift → karara bağlanmış teklifler + silme
                        } label: {
                            Image(systemName: "clock.arrow.circlepath") // SF Symbols: geçmiş ikonu
                        }
                    }
                } else { // Taşımacı
                    ToolbarItem(placement: .topBarLeading) { // Favoriler yalnız Taşımacı'da: sol üst kalp
                        NavigationLink { FavoritesView() } label: { Image(systemName: "heart") } // Views/FavoritesView.swift
                    }

                    // "Tekliflerim" düğmesi yalnız Taşımacı'da çıkar (Yük Veren'in + düğmesiyle aynı yer, roller farklı olduğu için çakışmaz)
                    ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe
                        NavigationLink { // basınca süslü parantezdeki ekrana geçer
                            MyOffersView() // Views/MyOffersView.swift → Taşımacı'nın tüm teklifleri (bekleyen/kabul/red) + silme
                        } label: { // label: düğmenin görünen kısmı
                            Image(systemName: "tray.full") // SF Symbols: gelen kutusu ikonu
                                .overlay(alignment: .topTrailing) { // .overlay [SWIFT]: ikonun ÜSTÜNE katman koyar | alignment: .topTrailing = sağ üst köşe
                                    if viewModel.unseenCount > 0 { // > büyüktür | görülmemiş karar varsa rozet çizilir, yoksa hiç çizilmez
                                        Text("\(viewModel.unseenCount)").font(.caption2).foregroundColor(.white) // rozetin içindeki sayı | ⮕ HomeViewModel.unseenCount ← OfferService.unseenCount() → UnseenCount.count
                                            .padding(4).background(Color.red).clipShape(Circle()) // .padding: etrafında boşluk | .background: kırmızı zemin | .clipShape(Circle()): yuvarlak yapar | Color [SWIFT]: renk | Circle [SWIFT]: daire şekli | .background [SWIFT]: arka plan | .clipShape [SWIFT]: görünümü şekle göre keser
                                            .offset(x: 10, y: -10) // .offset [SWIFT]: rozeti ikonun biraz sağ-üstüne kaydırır | x: sağa, y: yukarı (eksi)
                                    }
                                }
                        }
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
            .onAppear { PerfLog.mark("ana ekran göründü"); Task { await viewModel.loadUnread() } } // PerfLog: GEÇİCİ ölçüm ⮕ App/PerfLog.swift
            .task(id: viewModel.reloadKey) { // ⮕ HomeViewModel.reloadKey: bu yazı değişince load() yeniden çalışır
                await viewModel.load() // asıl iş ViewModel'de | aynı işi hem .task hem .refreshable çağırıyor, kod tekrarlanmasın | ⮕ HomeViewModel.load(coordinate:) → ilgili Service → APIClient → API
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

                // (14 Kasım) Dorse için ayrılmış boşluk KALDIRILDI (kullanıcı: "ayrı bir alanda değil"): dorse tüm ekranın arkasında (shipperBackground),
                //   içerik doğrudan onun üstünde akar; kartlar yarı şeffaf olduğu için dorse ve dolumu arkadan görünür.

                // 2) ANA EYLEM: üst çubuktaki + ile aynı yere gider; büyük düğme ilk ilanı verecek kişiye yolu gösterir
                NavigationLink { CreateListingView() } label: { // ⮕ Views/CreateListingView.swift
                    Label("Yeni ilan ver", systemImage: "plus.circle.fill") // Label [SWIFT]: simge + yazı
                        .font(.headline)
                        .foregroundStyle(palette.buttonText)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(palette.accent, in: .rect(cornerRadius: 14)) // LoginView'daki "Giriş yap" ile aynı düğme
                }

                if let listError = viewModel.listError { Text(listError).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez

                // 3) İLANLAR: başlıkta sayı | ⮕ HomeViewModel.listings ← load() ← ListingService.myListings() → GET /api/v1/listings/mine
                Text("İlanların (\(viewModel.listings.count))").font(.title3.bold()).foregroundStyle(palette.title)

                if viewModel.listings.isEmpty {
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
                                .background(palette.cardSurface.opacity(0.55), in: .rect(cornerRadius: 16)) // YARI ŞEFFAF (14 Kasım): kaydırınca arkadaki dorse kartların içinden görünür | koyu modda koyu, açıkta krem
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(palette.cardBorder))
                            }
                            .buttonStyle(.plain) // [SWIFT] NavigationLink yazıyı maviye boyamasın
                        }
                    }
                }
                // (14 Kasım) Model atıf yazısı ana ekrandan KALDIRILDI (kullanıcı istemedi) → Views/PrivacyView "Atıflar" bölümüne taşındı.
                //   CC-BY 4.0 lisansı uygulamada kaynağın adının geçmesini şart koşar; yeri serbest, silinemez.
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.load() } // aşağı çekince yenile (eski List'teki ile aynı iş)
    }

    // BU GÖRÜNÜM: Yük Veren ekranının TAM EKRAN arka planı (giriş ekranındaki SceneBackground gibi): renk geçişi + ışık haleleri + 3B dorse.
    // BAĞLANTI: body'deki .background { if isShipper { shipperBackground } } çağırır | renkler Design/DesignPalette.swift
    // DORSE: progress 1 sabit → koliler hazır olunca sırayla kasaya iner (TruckLoadRig.setProgress), sonra öyle kalır.
    //   Bir kez oynar: TruckLoadView'ın rig'i @State → ekran yenilense de (liste değişse de) yeniden oynamaz. Dokunuşa tepki yok (karar 13 Kasım).
    //   NEDEN veriye bağlı değil: iOS Listing modelinde ilan durumu yok; doluluk şimdilik süs.
    // YERLEŞİM (14 Kasım, kullanıcı: "ayrı bir alanda değil, arka planda dolacak"): 3B görünüm TÜM EKRANI kaplar (giriş ekranındaki koli sahnesi gibi);
    //   dorse ekranın ortasında durur, içerik (düğme, yarı şeffaf kartlar) onun üstünden akar. Önceden üstte 300 noktalık ayrı bir bölmedeydi.
    // ⮕ KULLANIM [shipperBackground]: kullanır: HomeView › body (.background)
    var shipperBackground: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        return ZStack {
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
            // Işık haleleri: dorsenin arkasında bulanık amber bulutlar (giriş ekranıyla aynı, ucuz 2B katman) → sahne daha aydınlık
            Ellipse().fill(palette.glowA).frame(width: 380, height: 320).blur(radius: 95).offset(x: -120, y: -40)
            Ellipse().fill(palette.glowB).frame(width: 360, height: 300).blur(radius: 95).offset(x: 130, y: 120)
            TruckLoadView(progress: 1) // ⮕ Design/TruckLoadView.swift (kamera dorseyi ekranın ENİNE sığdırır, dikeyde ortalar)
                .id(colorScheme) // görünüm (açık/koyu) değişince dorse sahnesi yeni renklerle yeniden kurulur (3B malzemeler kurulurken bir kez seçilir)
        }
        .ignoresSafeArea() // [SWIFT] çentik ve alt çubuk dahil tüm ekran
        .allowsHitTesting(false) // [SWIFT] arka plan dokunuş almaz → dokunuşlar üstteki düğme ve kartlara gider
    }
}
