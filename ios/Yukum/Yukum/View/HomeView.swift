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
        
                    if listings.isEmpty { // liste boş mu
                        Text("Şuan açılmış bir ilan yok.").foregroundColor(.secondary) // boşsa bu yazı görünür
                    }else {
                        
                        Text("Açık İlanlar").font(.title3).bold() // liste başlığı
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
            }
            .task { // .task [SWIFT]: ekran açılınca bir kez çalışır | içinde await kullanılabilir
                do { // do: dene | hata çıkarsa aşağıdaki catch'lerden biri çalışır
                    if user.role == "Shipper" { // VERİ kararı: rol hangi ucu çağıracağımızı belirler (yukarıdaki if yalnız çizim yapar)
                        // BAĞLANTI: Network/ListingService.swift → myListings → GET /api/v1/listings/mine (yalnız kendi ilanlarım)
                        listings = try await ListingService().myListings() // dönen liste @State'e yazılır, ekran yenilenir
                    } else {
                        // BAĞLANTI: Network/ListingService.swift → openListings → GET /api/v1/listings (tüm açık ilanlar, yalnız Carrier)
                        listings = try await ListingService().openListings()
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
