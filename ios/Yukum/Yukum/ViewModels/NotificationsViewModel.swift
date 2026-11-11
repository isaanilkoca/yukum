
//  NotificationsViewModel.swift
//  Yukum
//  Created by İsa Anıl Koca on 12.11.2026.


 /*

- private(set) var: Dışarıdan okunur ama yalnız bu sınıf değiştirebilir. Ekran isLoading'i görür, kendisi true yapamaz. items ve errorMessage düz var, çünkü testler ve ekran doğrudan dokunabiliyor.
- Hesaplanan özellik (var hasMore: Bool { ... }): Değer saklamaz, her okunduğunda hesaplanır. hasMore = "yüklenen sayı toplamdan az mı". Ayrı bir değişken tutsaydık güncellemeyi unutma riski olurdu.
- items.contains { !$0.isRead }: $0 closure'ın ilk parametresinin kısa adı. "İçinde okunmamış olan var mı" demek.
- defer { isLoading = false }: Fonksiyon nasıl biterse bitsin (başarı ya da hata) en sonda çalışır. Yükleniyor göstergesinin takılı kalmasını önler.
- guard ... else { return }: Şart sağlanmıyorsa erken çık. loadMore'da üç şartı tek satırda kontrol ediyor: daha var mı, zaten yüklenmiyor mu.
- Set(items.map(\.id)): \.id key path'tir, "her elemanın id'sini al" demek. Set içinde arama çok hızlıdır. İkinci sayfayı çekerken araya yeni bildirim girmişse aynı satır iki kez gelebilir, bunu eliyoruz.
- İyimser güncelleme: markRead önce ekranı günceller, sonra sunucuya sorar. Sunucu reddederse geri alır. Kullanıcı beklemez. Favori kalbinde yaptığının aynısı.
- let before = items: struct dizisi kopyalanır (değer tipi). Hata olursa items = before ile eski hâle dönmek bu yüzden bu kadar kolay.

 */

import Foundation
import Observation

// ┌─ BAĞLANTI HARİTASI: NotificationsViewModel ─────────────────────────────────────
// │ EKRAN     : Views/NotificationsView | SERVİS: Models/Services/NotificationService (NotificationServicing sözleşmesiyle)
// │ load()        →  service.list(page: 1)      →  GET /api/v1/notifications?page=1        →  items, totalCount
// │ loadMore()    →  service.list(page: page+1) →  GET /api/v1/notifications?page=2...     →  items'a eklenir
// │ markRead()    →  service.markRead(id:)      →  POST /api/v1/notifications/{id}/read    →  satır okundu (iyimser, hata olursa geri alınır)
// │ markAllRead() →  service.markAllRead()      →  POST /api/v1/notifications/read-all     →  hepsi okundu
// │ SAHTESİ   : YukumTests/Support/FakeNotificationService | TEST: YukumTests/ViewModels/NotificationsViewModelTests

@Observable // değişkenler değişince bunları okuyan ekran kendiliğinden yenilenir
final class NotificationsViewModel { //  bu sınıftan türetilemez
    private let service : NotificationServicing // sözleşmeye bağlı: gerçekte NotificationService, testte sahtesi
    
    var items : [AppNotification] = [] // ekrandaki satırlar
    var errorMessage : String? // string?: nil = hata yok
    private(set) var isLoading = false // private(set) [SWIFT]: dışarıdan okunur, yalnız bu sınıf değiştirir}
    private(set) var page = 1 // en son yüklenen sayfa
    private(set) var totalCount = 0 // sunucudaki toplam bildirim
    private(set) var isLoadingMore = false // devamı yükleniyor mu (çift isteği engeller)
    
    //Hesaplanan özellik : deger saklamaz her okundugunda hesaplanır
    
    var hasMore : Bool {items.count < totalCount}
    var hasUnread: Bool { items.contains { !$0.isRead } } // $0 [SWIFT]: closure'ın ilk parametresi | "okunmamış olan var mı"
 
    // Varsayılan parametre: ekranda NotificationsViewModel() yazılır (gerçek servis), testte sahtesi verilir
    init(service: NotificationServicing = NotificationService()) { self.service = service }
    
    // load: ilk sayfa | ÇAĞIRAN: NotificationsView .task ve .refreshable
      func load() async {
          errorMessage = nil
          isLoading = true
          defer { isLoading = false } // defer [SWIFT]: fonksiyon nasıl biterse bitsin en sonda çalışır
          do {
              let result = try await service.list(page: 1)
              items = result.items
              page = 1
              totalCount = result.totalCount
          } catch {
              if let message = error.userMessage { errorMessage = message } // userMessage: Models/Networking/Error+UserMessage
          }
      }
    
    // loadMore: sonraki sayfa | ÇAĞIRAN: listenin son satırı göründüğünde
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return } // guard [SWIFT]: şart sağlanmazsa erken çık
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await service.list(page: page + 1)
            let known = Set(items.map(\.id)) // \.id [SWIFT]: key path, "her elemanın id'si" | Set: hızlı arama
            items += result.items.filter { !known.contains($0.id) } // araya yeni bildirim girdiyse tekrar gelen satırı ele
            page += 1
            totalCount = result.totalCount
        } catch {
            if let message = error.userMessage { errorMessage = message }
        }
    }
    
    // markRead: satıra basınca | iyimser güncelleme: önce ekran, sonra sunucu; reddedilirse geri al
     func markRead(_ item: AppNotification) async {
         guard !item.isRead, let index = items.firstIndex(where: { $0.id == item.id }) else { return } // zaten okunduysa istek atma
         items[index].isRead = true
         do {
             try await service.markRead(id: item.id)
         } catch {
             if let again = items.firstIndex(where: { $0.id == item.id }) { items[again].isRead = false } // liste değişmiş olabilir: yeri yeniden bul
             if let message = error.userMessage { errorMessage = message }
         }
     }
    
    func markAllRead() async {
           guard hasUnread else { return } // okunmamış yoksa istek atma
           let before = items // struct dizisi KOPYALANIR (değer tipi): geri almak için eski hâl
           for index in items.indices { items[index].isRead = true } // .indices [SWIFT]: 0..<count
           do {
               try await service.markAllRead()
           } catch {
               items = before
               if let message = error.userMessage { errorMessage = message }
           }
       }
   }
    

