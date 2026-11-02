//
//  HomeView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: giriş sonrası ana ekran. Rol "Shipper" ise Yük Veren, değilse Taşımacı anasayfası gösterir.
// BAĞLANTI: View/LoginView.swift giriş başarılı olunca .fullScreenCover ile bu ekranı açar ve giriş yapan kullanıcıyı verir.
struct HomeView: View { // HomeView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // user: giriş yapan kişi (ad, rol) | kalıbı: Network/LoginRequest.swift → struct LoginUser
    // let [SWIFT]: değişmeyen değer | dışarıdan verilir: LoginView'daki "loggedInUser" dolunca HomeView(user: user) ile buraya gelir
    let user: LoginUser

    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer al | dismiss: "bu ekranı kapat" komutu | çıkışta kullanılır
    
    @State private var listings: [Listing] = [] // @State [SWIFT]: ekranın hafızası | [Listing] = ilan listesi, başta boş | kalıbı: Network/ListingRequest.swift | doldurulduğu yer: aşağıdaki .task
    @State private var listError: String? // liste yüklenemezse kırmızı yazılacak mesaj | nil: hata yok
    // unseenCount: Taşımacı'nın henüz görmediği karar (kabul/red) sayısı
    // NE İŞE YARAR: sağ üstteki kutu ikonunda kırmızı rozet olarak gösterilir (push bildirim yerine uygulama içi bildirim) | 0 ise rozet çizilmez
    // NEREDE DOLAR: aşağıdaki .task, Taşımacı kolu → OfferService().unseenCount() | NEREDE KULLANILIR: toolbar'daki Image("tray.full").overlay
    @State private var unseenCount = 0 // @State: değişince ekran yenilenir | başta 0
    
    // ─── Taşımacı ilan filtresi: kalkış ili / ilçesi ───
     // cities: filtredeki il listesi | NE İŞE YARAR: il Picker'ı bundan çizilir | NEREDE DOLAR: aşağıdaki .task, ilk açılışta CityService().cities() ile | başta boş []
     @State private var cities: [City] = [] // @State [SWIFT]: değişince ekran yenilenir | City kalıbı: Network/CityModels.swift
     // filterDistricts: seçilen ilin ilçeleri | NE İŞE YARAR: ilçe Picker'ı bundan çizilir | NEREDE DOLAR: il Picker'ındaki .onChange, il seçilince
     @State private var filterDistricts: [District] = []
     // filterCityId / filterDistrictId: seçili il ve ilçe numarası | 0 = "Tümü" (filtre yok) | NE İŞE YARAR: hem Picker'ların seçimini tutar hem de API'ye gönderilecek filtredir | NEREDE KULLANILIR: aşağıdaki .task(id:) ve openListings çağrısı
     @State private var filterCityId = 0
     @State private var filterDistrictId = 0

    var body: some View { // ekranın içeriği

        NavigationStack { // NavigationStack [SWIFT]: ekranlar arası geçiş + geri oku yönetir | NavigationLink'ler bunun içinde çalışır

            VStack(spacing: 24) { // elemanları alt alta dizer

                Text("Hoş Geldin \(user.displayName)").font(.title2).bold() // \( ) = yazının içine değişken koyar | user.displayName: LoginUser'daki ad alanı

                // user.role API'den "Shipper" ya da "Carrier" gelir | yazımı API ile birebir aynı olmalı
                if user.role == "Shipper" { // GÖRÜNÜM kararı: ekranda ne ÇİZİLECEK | Yük Veren ilan listesini görür, Taşımacı aşağıdaki else'teki yazıyı | == karşılaştırır

                    if let listError { Text(listError).foregroundColor(.red)} // doluysa kırmızı yaz, nil ise çizilmez
                    
                    
                    if listings.isEmpty { // isempty liste bos mu
                        Text("Henüz ilanın yok, ilk ilanını ver.").foregroundColor(.secondary)  // boşsa bu yazı görünür // .secondary [SWIFT]: gri, ikincil yazı rengi | boş durum mesajı dikkat çekmesin
                        
                    } else {
                        HStack{
                            Text("Eski İlanların ").font(.title3).bold()
                            Image(systemName: "shippingbox.fill")
                            Text("->")
                            Image(systemName: "truck.box.fill")
                        }
                        
                        List(listings) { listing in // List [SWIFT]: kaydırılabilir satır listesi | listing: o anki ilan
                            NavigationLink { // satıra basınca süslü parantezdeki ekrana geçer
                                ListingOffersView(listing: listing) // View/ListingOffersView.swift → bu ilanın gelen teklifleri | basılan ilanı VERİYORUZ
                            } label: { // label: satırın görünen kısmı
                                ListingRow(listing: listing) // BAĞLANTI: View/ListingRow.swift → tek satırı o çizer, ilanı ona VERİYORUZ (listing: parametre adı)
                            }
                        }.listStyle(.plain) // .plain: düz beyaz arka plan, satırlar arası ince çizgi | varsayılan (.insetGrouped) gri zemin çizerdi
                    }
                    
                } else { // Shipper değilse (Carrier)
                    if let listError {Text(listError).foregroundColor(.red)} // hata varsa kırmızı yaz (Yük Veren ile aynı değişken)
        
                    Text("Açık İlanlar").font(.title3).bold() // liste başlığı | boş olsa da görünsün diye if listings.isEmpty'nin DIŞINA taşındı
                    
                    // ─── FİLTRE: kalkış ili + ilçesi | NEDEN if listings.isEmpty'nin ÜSTÜNDE: filtre sonucu boş çıkarsa Picker'lar da kaybolmasın, kullanıcı filtreyi geri alabilsin ───
                    HStack{  // HStack [SWIFT]: yan yana dizer | il ve ilçe Picker'ları yan yana
                        Picker("İl",selection: $filterCityId){ // Picker [SWIFT]: açılır liste | selection: seçilen değer $filterCityId'ye yazılır ($ = iki yönlü bağ)
                            Text("Tüm İller").tag(0) // tag(0): "Tümü" seçeneği, değeri 0 = filtre yok
                            ForEach(cities) { city in // ForEach [SWIFT]: listedeki her il için bir satır çizer | cities: .task'ta dolan liste
                                Text(city.name).tag(city.id) // city.name: ekranda görünen ad | tag(city.id): seçilince değişkene yazılacak numara
                                
                            }
                            
                        }
                        .pickerStyle(.menu) // açılır menü görünümü
                        // .onChange [SWIFT]: değişkeni izler, değişince BİR KEZ çalışır | il değişince ilçe seçimi sıfırlanır ve yeni ilin ilçeleri çekilir (CreateListingView'daki mantığın aynısı)
                        .onChange(of: filterCityId){ _,newId in  // _ = eski değer (kullanmıyoruz) | newId = yeni değer
                            filterDistrictId = 0 // eski ilin ilçesi yeni ile ait değil, sıfırla
                            filterDistricts = [] // eski ilçe listesini boşalt
                            if newId == 0 {return} // "Tüm İller"e dönüldüyse çekecek ilçe yok | return = bloktan çık
                            Task { // Task [SWIFT]: .onChange bekleyemez, internet isteği await ister; await yalnız Task içinde yazılır
                                // BAĞLANTI: Network/CityService.swift → districts → GET /api/v1/cities/{id}/districts | try? hata olursa nil | ?? [] nil ise boş liste
                                filterDistricts = (try? await CityService().districts(cityId: newId)) ?? []
                            }
                            
                        }
                        if filterCityId != 0 { // il seçilmeden picker çizilmez
                            Picker("İlçe",selection: $filterDistrictId){ // seçilen ilçe numarası $filterDistrictId'ye yazılır
                                Text("Tüm İlçeler").tag(0) // 0 = ilçe filtresi yok
                                ForEach(filterDistricts) { district in // il Picker'ındaki .onChange'in doldurduğu liste
                                    Text(district.name).tag(district.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                    }
                    
                    
                    if listings.isEmpty { // liste boş mu
                        Text("Şuan açılmış bir ilan yok.").foregroundColor(.secondary) // boşsa bu yazı görünür
                    }else {
                        
                        List(listings) { listing in // Yük Veren listesiyle aynı yapı, farkı: bu liste tüm açık ilanlar (openListings)
                            NavigationLink { // NavigationLink [SWIFT]: satıra basınca süslü parantezdeki ekrana geçer
                                ListingDetailView(listing: listing) // View/ListingDetailView.swift → basılan ilanı detay ekranına VERİYORUZ
                            } label: { // label: satırın görünen kısmı
                                ListingRow(listing: listing) // eski satır aynen kalır
                            }
                        }.listStyle(.plain)
                    }
                    
                }

                Button("Çıkış Yap") { // Button [SWIFT]: tıklanınca süslü parantezdeki kod çalışır
                    dismiss() // bu ekranı kapatır → LoginView'daki loggedInUser nil olur → giriş ekranına dönülür
                }.buttonStyle(.borderedProminent)

            }.padding()
            .navigationTitle("Yüküm") // [SWIFT] üst çubuktaki başlık
            .toolbar { // .toolbar [SWIFT]: üst çubuğa eleman koyar
                if user.role == "Shipper" { // yalnız Yük Veren ilan açabilir
                    ToolbarItem(placement: .topBarTrailing) { // ToolbarItem [SWIFT]: çubuktaki bir eleman | placement: nerede durur | .topBarTrailing: sağ üst köşe
                        NavigationLink { // basınca süslü parantezdeki ekrana geçer
                            CreateListingView() // View/CreateListingView.swift → yeni ilan formu | () = ekrandan bir örnek üret
                        } label: { // label: düğmenin görünen kısmı (yazı yerine ikon koyacağımız için ayrı yazılır)
                            Image(systemName: "plus") // Image(systemName:) [SWIFT]: Apple'ın hazır ikon kütüphanesi (SF Symbols) | "plus": + işareti
                        }
                    }
                }
                
                if user.role == "Shipper" { // GÖRÜNÜM kararı: "Eski teklifler" yalnız Yük Veren'de çıkar
                                 ToolbarItem(placement: .topBarLeading) { // .topBarLeading [SWIFT]: sol üst köşe (sağ üstte + var)
                                     NavigationLink { // basınca süslü parantezdeki ekrana geçer
                                         OldOffersView() // View/OldOffersView.swift → karara bağlanmış teklifler + silme
                                     } label: {
                                         Image(systemName: "clock.arrow.circlepath") // SF Symbols: geçmiş ikonu
                                     }
                                 }
                             }

                if user.role == "Carrier" { // GÖRÜNÜM kararı: "Tekliflerim" düğmesi yalnız Taşımacı'da çıkar (Yük Veren'in + düğmesiyle aynı yer, roller farklı olduğu için çakışmaz)
                    ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe
                        NavigationLink { // basınca süslü parantezdeki ekrana geçer
                            MyOffersView() // View/MyOffersView.swift → Taşımacı'nın tüm teklifleri (bekleyen/kabul/red) + silme
                        } label: { // label: düğmenin görünen kısmı
                            Image(systemName: "tray.full") // SF Symbols: gelen kutusu ikonu
                                .overlay(alignment: .topTrailing) { // .overlay [SWIFT]: ikonun ÜSTÜNE katman koyar | alignment: .topTrailing = sağ üst köşe
                                    if unseenCount > 0 { // > büyüktür | görülmemiş karar varsa rozet çizilir, yoksa hiç çizilmez
                                        Text("\(unseenCount)").font(.caption2).foregroundColor(.white) // rozetin içindeki sayı | \( ) = değişkeni yazıya koyar
                                            .padding(4).background(Color.red).clipShape(Circle()) // .padding: etrafında boşluk | .background: kırmızı zemin | .clipShape(Circle()): yuvarlak yapar
                                            .offset(x: 10, y: -10) // .offset [SWIFT]: rozeti ikonun biraz sağ-üstüne kaydırır | x: sağa, y: yukarı (eksi)
                                    }
                                }
                        }
                    }
                }
            }
            // .task(id:) [SWIFT]: .task ile aynı (ekran HER göründüğünde çalışır: ilk açılış + başka ekrandan geri dönünce) + id DEĞİŞİNCE de yeniden çalışır
            // NE İŞE YARAR: il ya da ilçe Picker'ı değişince liste kendiliğinden yeniden çekilir, ayrı "Ara" düğmesi gerekmez | teklif verip/karar verip dönünce de liste ve rozet yenilenir
            // id: filtre seçimlerini birleştiren yazı | "\( )" = değişkenleri yazıya koyar | örn. "33-0" | bu yazı değişince blok yeniden çalışır
            .task(id: "\(filterCityId)-\(filterDistrictId)") { // içinde await kullanılabilir
                do { // do: dene | hata çıkarsa aşağıdaki catch'lerden biri çalışır
                    if user.role == "Shipper" { // VERİ kararı: rol hangi ucu çağıracağımızı belirler (yukarıdaki if yalnız çizim yapar)
                        // BAĞLANTI: Network/ListingService.swift → myListings → GET /api/v1/listings/mine (yalnız kendi ilanlarım)
                        listings = try await ListingService().myListings() // dönen liste @State'e yazılır, ekran yenilenir
                    } else {
                        // BAĞLANTI: Network/ListingService.swift → openListings(fromCityId:fromDistrictId:) → GET /api/v1/listings?fromCityId=..&fromDistrictId=.. (açık ilanlar, yalnız Carrier) | 0 = filtre yok = tüm ilanlar
                        listings = try await ListingService().openListings(fromCityId: filterCityId, fromDistrictId: filterDistrictId)
                        if cities.isEmpty { cities = (try? await CityService().cities()) ?? [] } // il listesi yalnız bir kez yüklenir, her yenilemede tekrar çekilmez | isEmpty: liste boş mu | try?: hata olursa nil | ?? []: nil ise boş liste
                        unseenCount = try await OfferService().unseenCount() // BAĞLANTI: Network/OfferService.swift → GET /api/v1/offers/mine/unseen-count | dönen sayı @State'e yazılır, rozet güncellenir
                    }
                } catch let error as AuthError { // HATA YOLU: API hata verirse ListingService "throw AuthError(...)" yapar, burada yakalanır | AuthError: Network/AuthService.swift'te tanımlı
                    listError = error.message // mesajı listError'a yaz | @State olduğu için ekran yenilenir, "if let listError" kırmızı yazıyı çizer
                } catch { // başka her hata: API kapalı, internet yok
                    listError = "Sunucuya ulaşılamadı." // sabit mesaj
                }
            }
        }
    }
}
