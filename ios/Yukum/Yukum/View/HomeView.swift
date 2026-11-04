//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi
import CoreLocation // [SWIFT] konum çerçevesi | burada yalnız izin durumunu (.denied) karşılaştırmak için gerekli

// BU EKRAN: giriş sonrası ana ekran. Rol "Shipper" ise Yük Veren, değilse Taşımacı anasayfası gösterir.
// MVVM: bu dosya yalnız GÖRÜNÜM (ne çizilecek). Durum ve iş mantığı (hangi liste, hangi filtre, ne zaman yüklenir, hata yazısı) ViewModel/HomeViewModel.swift'te.
// BAĞLANTI: View/LoginView.swift giriş başarılı olunca .fullScreenCover ile bu ekranı açar ve giriş yapan kullanıcıyı verir.
struct HomeView: View { // HomeView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (her yenilemede yeni ViewModel oluşmaz)
    // @Observable olduğu için viewModel içindeki değişkenler değişince bu ekran kendiliğinden yenilenir
    @State private var viewModel: HomeViewModel

    // locationManager: konum motorumuz | NE İŞE YARAR: izin ister, konumu bulur, coordinate/status/errorMessage değişince ekran yenilenir (@Observable)
    // NEDEN burada (ViewModel'de değil): izin penceresi ve Ayarlar'a gitme gibi iOS'a özgü arayüz işleridir | ViewModel yalnız bulunan konumu parametre olarak alır, böylece testte sahte konum verilebilir | BAĞLANTI: Location/LocationManager.swift
    @State private var locationManager = LocationManager()

    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer al | dismiss: "bu ekranı kapat" komutu | çıkışta kullanılır
    @Environment(\.openURL) private var openURL // openURL: bir adresi açar | burada iOS Ayarlar uygulamasını açmak için kullanılır

    // init: dışarıdan "user" verilir (LoginView: HomeView(user: user)), ViewModel burada oluşturulur
    // State(initialValue:): @State'i elle başlatma yolu | kalıbı: Network/LoginRequest.swift → struct LoginUser
    init(user: LoginUser) {
        _viewModel = State(initialValue: HomeViewModel(user: user))
    }

    // coordinate: telefonun bulunan konumu (enlem, boylam) ya da nil | NEDEN ayrı: CLLocationCoordinate2D karşılaştırılamaz/Equatable değil, ViewModel'e sade bir çift olarak veriyoruz
    private var coordinate: (latitude: Double, longitude: Double)? {
        locationManager.coordinate.map { (latitude: $0.latitude, longitude: $0.longitude) } // .map: nil değilse dönüştür
    }

    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable bir sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (Picker/Toggle seçimi doğrudan ViewModel'e yazılsın diye)
        @Bindable var viewModel = viewModel

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | NavigationLink'ler bunun içinde çalışır

            VStack(spacing: 24) { // elemanları alt alta dizer

                Text("Hoş Geldin \(viewModel.user.displayName)").font(.title2).bold() // \( ) = yazının içine değişken koyar | LoginUser'daki ad alanı

                // user.role API'den "Shipper" ya da "Carrier" gelir | yazımı API ile birebir aynı olmalı
                if viewModel.isShipper { // GÖRÜNÜM kararı: ekranda ne ÇİZİLECEK | Yük Veren ilan listesini görür, Taşımacı aşağıdaki else'teki yazıyı

                    if let listError = viewModel.listError { Text(listError).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez

                    if viewModel.listings.isEmpty { // liste boş mu
                        Text("Henüz ilanın yok, ilk ilanını ver.").foregroundColor(.secondary) // boşsa bu yazı görünür | .secondary [SWIFT]: gri, ikincil yazı rengi

                    } else {
                        HStack {
                            Text("Eski İlanların ").font(.title3).bold()
                            Image(systemName: "shippingbox.fill")
                            Text("->")
                            Image(systemName: "truck.box.fill")
                        }

                        List(viewModel.listings) { listing in // List [SWIFT]: kaydırılabilir satır listesi | listing: o anki ilan
                            NavigationLink { // satıra basınca süslü parantezdeki ekrana geçer
                                ListingOffersView(listing: listing) // View/ListingOffersView.swift → bu ilanın gelen teklifleri | basılan ilanı VERİYORUZ
                            } label: { // label: satırın görünen kısmı
                                ListingRow(listing: listing) // BAĞLANTI: View/ListingRow.swift → tek satırı o çizer, ilanı ona VERİYORUZ (listing: parametre adı)
                            }
                        }.listStyle(.plain) // .plain: düz beyaz arka plan, satırlar arası ince çizgi | varsayılan (.insetGrouped) gri zemin çizerdi
                        .refreshable { await viewModel.load(coordinate: coordinate) } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince iş çalışır, yenileme çarkı iş bitince kendiliğinden kapanır | NE İŞE YARAR: kullanıcı, otomatik yenilemeyi beklemeden güncel veriyi kendisi ister
                    }

                } else { // Shipper değilse (Carrier)
                    if let listError = viewModel.listError { Text(listError).foregroundColor(.red) } // hata varsa kırmızı yaz (Yük Veren ile aynı değişken)

                    Text("Açık İlanlar").font(.title3).bold() // liste başlığı | boş olsa da görünsün diye if listings.isEmpty'nin DIŞINDA

                    // ─── FİLTRE: kalkış ili + ilçesi | NEDEN if listings.isEmpty'nin ÜSTÜNDE: filtre sonucu boş çıkarsa Picker'lar da kaybolmasın, kullanıcı filtreyi geri alabilsin ───
                    HStack { // HStack [SWIFT]: yan yana dizer | il ve ilçe Picker'ları yan yana
                        Picker("İl", selection: $viewModel.filterCityId) { // Picker [SWIFT]: açılır liste | selection: seçilen değer ViewModel'deki filterCityId'ye yazılır ($ = iki yönlü bağ)
                            Text("Tüm İller").tag(0) // tag(0): "Tümü" seçeneği, değeri 0 = filtre yok
                            ForEach(viewModel.cities) { city in // ForEach [SWIFT]: listedeki her il için bir satır çizer | cities: ViewModel.load'da dolan liste
                                Text(city.name).tag(city.id) // city.name: ekranda görünen ad | tag(city.id): seçilince değişkene yazılacak numara
                            }
                        }
                        .pickerStyle(.menu) // açılır menü görünümü
                        // .onChange [SWIFT]: değişkeni izler, değişince BİR KEZ çalışır | il değişince ViewModel ilçe seçimini sıfırlar ve yeni ilin ilçelerini çeker (mantık ViewModel'de, burada yalnız tetikleme)
                        .onChange(of: viewModel.filterCityId) { _, newId in // _ = eski değer (kullanmıyoruz) | newId = yeni değer
                            Task { await viewModel.cityFilterChanged(to: newId) } // Task [SWIFT]: .onChange bekleyemez, internet isteği await ister; await yalnız Task içinde yazılır
                        }
                        if viewModel.filterCityId != 0 { // il seçilmeden ilçe Picker'ı çizilmez
                            Picker("İlçe", selection: $viewModel.filterDistrictId) { // seçilen ilçe numarası ViewModel'e yazılır
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
                    Toggle("Yakınımdakiler", isOn: $viewModel.nearMe)
                        // .onChange: nearMe değişince BİR KEZ çalışır | on: yeni değer
                        // açıldıysa konum motoruna "izin sor ve konumu bul" deriz (izin ya da konum gelene kadar liste eskisi gibi kalır, gelince .task(id:) listeyi yeniler)
                        .onChange(of: viewModel.nearMe) { _, on in
                            if on { locationManager.request() }
                        } // NOT: ekrana bir şey ÇİZEN kod (Text, HStack) .onChange'in içine yazılmaz, çünkü orası "olunca çalışacak iş" bloğu, çizim bloğu değil | mesajlar aşağıda, dışarıda

                    // izin/konum mesajları: locationManager.status ve errorMessage @Observable olduğu için değişince bu bloklar kendiliğinden yeniden değerlendirilir
                    if viewModel.nearMe && locationManager.status == .denied { // izin reddedilmişse (kodla tekrar sorulamaz, yalnız Ayarlar'dan açılır)
                        HStack {
                            Text("Konum izni kapalı").font(.caption).foregroundColor(.red)
                            // Button: basınca iOS Ayarlar uygulamasında bu uygulamanın sayfasını açar | UIApplication.openSettingsURLString: Apple'ın hazır "ayarlar" adresi
                            Button("Ayarları aç") { openURL(URL(string: UIApplication.openSettingsURLString)!) }.font(.caption)
                        }
                    } else if viewModel.nearMe, let message = locationManager.errorMessage { // else if: ya da | konum alınamadıysa (GPS yok vb.) hata yazısı
                        Text(message).font(.caption).foregroundColor(.red)
                    }

                    if viewModel.listings.isEmpty { // liste boş mu
                        Text("Şuan açılmış bir ilan yok.").foregroundColor(.secondary) // boşsa bu yazı görünür
                    } else {
                        List(viewModel.listings) { listing in // Yük Veren listesiyle aynı yapı, farkı: bu liste teklif vermediğin açık ilanlar
                            NavigationLink { // NavigationLink [SWIFT]: satıra basınca süslü parantezdeki ekrana geçer
                                ListingDetailView(listing: listing) // View/ListingDetailView.swift → basılan ilanı detay ekranına VERİYORUZ
                            } label: { // label: satırın görünen kısmı
                                ListingRow(listing: listing) // eski satır aynen kalır
                            }
                        }.listStyle(.plain)
                        .refreshable { await viewModel.load(coordinate: coordinate) } // aşağı çekince yenile
                    }
                }

                Button("Çıkış Yap") { // Button [SWIFT]: tıklanınca süslü parantezdeki kod çalışır
                    // ÇIKIŞ: önce yerel oturum silinir (Keychain + bellek), sonra sunucuya haber verilir (jeton orada da iptal edilsin) | BAĞLANTI: Network/AuthSession.swift → signOut
                    Task { // Task [SWIFT]: düğmede await kullanmamızı sağlar
                        await AuthSession.shared.signOut()
                        dismiss() // bu ekranı kapatır → LoginView'daki loggedInUser nil olur → giriş ekranına dönülür
                    }
                }.buttonStyle(.borderedProminent)

            }.padding()
            // .onReceive [SWIFT]: bir "yayını" dinler | oturum yenilenemezse (süre doldu, jeton iptal edildi/çalıntı sanıldı) AuthSession "sessionExpired" yayınlar
            // → ekran kapanır ve kullanıcı giriş ekranına döner (jeton zaten silindi) | NEDEN gerekli: arka plandaki istekler 401 alıp yenileyemediğinde kullanıcı boşta kalmasın
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in dismiss() }
            .navigationTitle("Yüküm") // [SWIFT] üst çubuktaki başlık
            .toolbar { // .toolbar [SWIFT]: üst çubuğa eleman koyar
                if viewModel.isShipper { // yalnız Yük Veren ilan açabilir
                    ToolbarItem(placement: .topBarTrailing) { // ToolbarItem [SWIFT]: çubuktaki bir eleman | placement: nerede durur | .topBarTrailing: sağ üst köşe
                        NavigationLink { // basınca süslü parantezdeki ekrana geçer
                            CreateListingView() // View/CreateListingView.swift → yeni ilan formu | () = ekrandan bir örnek üret
                        } label: { // label: düğmenin görünen kısmı (yazı yerine ikon koyacağımız için ayrı yazılır)
                            Image(systemName: "plus") // Image(systemName:) [SWIFT]: Apple'ın hazır ikon kütüphanesi (SF Symbols) | "plus": + işareti
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) { // GÖRÜNÜM kararı: "Eski teklifler" yalnız Yük Veren'de çıkar | .topBarLeading: sol üst köşe (sağ üstte + var)
                        NavigationLink {
                            OldOffersView() // View/OldOffersView.swift → karara bağlanmış teklifler + silme
                        } label: {
                            Image(systemName: "clock.arrow.circlepath") // SF Symbols: geçmiş ikonu
                        }
                    }
                } else { // Taşımacı
                    // "Tekliflerim" düğmesi yalnız Taşımacı'da çıkar (Yük Veren'in + düğmesiyle aynı yer, roller farklı olduğu için çakışmaz)
                    ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe
                        NavigationLink { // basınca süslü parantezdeki ekrana geçer
                            MyOffersView() // View/MyOffersView.swift → Taşımacı'nın tüm teklifleri (bekleyen/kabul/red) + silme
                        } label: { // label: düğmenin görünen kısmı
                            Image(systemName: "tray.full") // SF Symbols: gelen kutusu ikonu
                                .overlay(alignment: .topTrailing) { // .overlay [SWIFT]: ikonun ÜSTÜNE katman koyar | alignment: .topTrailing = sağ üst köşe
                                    if viewModel.unseenCount > 0 { // > büyüktür | görülmemiş karar varsa rozet çizilir, yoksa hiç çizilmez
                                        Text("\(viewModel.unseenCount)").font(.caption2).foregroundColor(.white) // rozetin içindeki sayı
                                            .padding(4).background(Color.red).clipShape(Circle()) // .padding: etrafında boşluk | .background: kırmızı zemin | .clipShape(Circle()): yuvarlak yapar
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
            .task(id: viewModel.reloadKey(coordinate: coordinate)) {
                await viewModel.load(coordinate: coordinate) // asıl iş ViewModel'de | aynı işi hem .task hem .refreshable çağırıyor, kod tekrarlanmasın
            }
        }
    }
}
