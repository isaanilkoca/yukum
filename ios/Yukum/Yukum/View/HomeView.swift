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
    
    @State private var listings: [MyListing] = [] // @State [SWIFT]: ekranın hafızası | [MyListing] = ilan listesi, başta boş | kalıbı: Network/ListingRequest.swift | doldurulduğu yer: aşağıdaki .task
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
                        List(listings) { listing in // List [SWIFT]: kaydırılabilir satır listesi | listings: her eleman için bir satır, Identifiable olduğu için id: yazmak gerekmez | listing: o anki ilan (adı bizim)
                            VStack(alignment: .leading, spacing: 6) { // alt alta, sola hizalı | spacing: satırlar arası boşluk 4 → 6
                                Text(listing.title).font(.headline) // başlık: kalın ve büyük
                                Text("\(listing.fromCityName) → \(listing.toCityName)").font(.subheadline) // "Mersin → İstanbul" | .subheadline: orta boy yazı | -> yerine → (ok işareti)
                                Text("\(listing.weightKg) kg · \(listing.pickupDate)").font(.caption).foregroundColor(.secondary) // küçük, gri yazı | · = araya nokta ayracı (. yerine)
                            }.padding(.vertical, 4) // padding(.vertical, 4): satırın üstüne ve altına 4 nokta boşluk | satırlar birbirine yapışmaz
                        }.listStyle(.plain) // .listStyle [SWIFT]: listenin görünüm stili | .plain: düz beyaz arka plan, satırlar arası ince çizgi | varsayılan (.insetGrouped) gri zemin üzerinde yuvarlak kutular çizer, o yüzden gri görünüyordu
                    }
                } else { // Shipper değilse (Carrier)
                    Text("Taşımacı AnaSayfası") // sonra açık ilanlar listesi gelecek
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
                if user.role == "Shipper"{ // VERİ kararı: hangi isteğin atılacağı | ilanlarım ucu yalnız Yük Veren'e açık; Taşımacı için atılırsa API 403 döner ve ekrana boşuna hata çıkar | yukarıdaki if yalnız çizim yapar, .task ise çizimden bağımsız, ekran açılınca kendi başına çalışır
                    do {
                        // BAĞLANTI: ListingService().myListings() → Network/ListingService.swift'teki func myListings → jetonla GET /api/v1/listings/mine → [MyListing] döner
                        listings = try await ListingService().myListings() // dönen liste @State'e yazılır, ekran yenilenir
                    }catch let error as AuthError {  // HATA YOLU: API hata verirse ListingService.myListings "throw AuthError(...)" yapar, burada yakalanır | AuthError: Network/AuthService.swift'te tanımlı
                        listError = error.message // mesajı listError'a yaz | @State olduğu için ekran yenilenir, yukarıdaki "if let listError" kırmızı yazıyı çizer
                    } catch {
                        listError = "Sunucuya ulaşılamadı" // başka her hata: API kapalı, internet yok (sabit mesaj)
                    }
                }
                
            }
        }
    }
}
