//
//  ChatView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI


// BU EKRAN: bir teklifin sohbeti. Yük Veren ile teklifi veren Taşımacı yazışır. Mesajlar balon olarak çizilir, ekran açıkken 3 sn'de bir yenilenir.
// BAĞLANTI: View/ListingOffersView.swift (Yük Veren) ve View/MyOffersView.swift (Taşımacı) "Sohbet" düğmesiyle bu ekranı açar (sonraki adım)
// Veri: Network/ChatService.swift → messages, send | kalıplar: Network/ChatModels.swift → ChatMessage, SendMessageRequest
//
// SOHBET MANTIĞI (4 adım, bir kere anlayınca hepsi aynı):
//   1) EKRAN AÇILINCA  → mesajları API'den çek (GET), messages listesine yaz
//   2) GÖNDERİNCE      → yazıyı API'ye yolla (POST), sonra listeyi yeniden çek
//   3) KARŞI TARAFIN MESAJI → sunucu "push" yapmaz; biz 3 sn'de bir tekrar sorarız (polling) | canlı bağlantı yok, basit yöntem
//   4) ÇİZİM           → her mesaj isMine'a bakılıp sağa (benim) ya da sola (karşı taraf) yaslı balon olur

struct ChatView: View {
    
    
    let offerId: String // hangi teklifin sohbeti | NE İŞE YARAR: API adresine girer /offers/{offerId}/messages | NEREDE: dışarıdan verilir (düğmeyi çizen ekran)
    let title: String // üst çubukta görünecek başlık (ilan adı) | dışarıdan verilir
    // canComplete: "İşi Bitir ve Sil" seçeneği gösterilsin mi | NE İŞE YARAR: yalnız KABUL EDİLMİŞ (aktif) tekliflerde true; bekleyen/reddedilen/tamamlanmışta menüde bu seçenek çıkmaz | dışarıdan verilir
    let canComplete: Bool
    let canWrite: Bool // yazma açık mı (NEDEN dışarıdan veriliyor: ChatView teklifin durumunu bilmez, onu açan ekran bilir; bu yüzden hazır karar olarak alır) | NE İŞE YARAR: reddedilmiş tekliflerde false olur, yazma kutusu gizlenir, yalnız eski mesajlar okunur | API de 409 ile reddeder
    
    // messages: sohbetin mesaj listesi | NE İŞE YARAR: balonlar bundan çizilir; değişince ekran yenilenir (@State) | NEREDE DOLAR: loadMessages() API'den çekip yazar | başta boş []
       @State private var messages: [ChatMessage] = [] // @State [SWIFT]: ekranın hafızası

       // draft: yazma kutusundaki henüz gönderilmemiş metin | NE İŞE YARAR: TextField buna bağlı ($draft), kullanıcı yazdıkça dolar | Gönder'e basınca okunup boşaltılır
       @State private var draft = ""

       // errorMessage: kırmızı hata yazısı | NE İŞE YARAR: yükleme/gönderme başarısız olursa sebebi gösterir | NEREDE DOLAR: loadMessages() ve send() catch blokları
       @State private var errorMessage: String? // String? = boş olabilir | nil: hata yok

    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer | dismiss: "bu ekranı kapat" komutu | iş bitirilince sohbetten geri dönmek için
    // showClearConfirm: "Mesajları Temizle" onay penceresi açık mı | true olunca pencere çıkar, seçim yapılınca SwiftUI kendisi false yapar
    // NEDEN onay penceresi: silme geri alınamaz, yanlışlıkla basılmasın
    @State private var showClearConfirm = false
    // showCompleteConfirm: "İşi Bitir ve Sil" onay penceresi açık mı | bu işlem daha ağır (iki tarafta durumu değiştirir), ayrı ve daha açıklayıcı bir pencereyle sorulur
    @State private var showCompleteConfirm = false
    // locked: sohbet bu ekran AÇIKKEN kilitlendi mi | NE İŞE YARAR: karşı taraf işi bitirirse (ya da teklif reddedilirse) biz yazmaya çalışınca sunucu "sohbet kapalı" der, o zaman bu true olur ve yazma kutusu kapanır
    // NEDEN ayrı: canWrite ekran açılırken verilen sabit değer; durum açıkken değişirse onu yakalayan bu
    @State private var locked = false
    
    
    var body: some View {
        
        VStack(spacing: 0){
            ScrollViewReader{ proxy in // ScrollViewReader [SWIFT]: kaydırmayı KODLA yönetmeye yarar | proxy: kaydırma kumandası (adı bizim) | yeni mesaj gelince en alta inmek için
                ScrollView{ // ScrollView [SWIFT]: kaydırılabilir alan | mesajlar ekrana sığmayınca yukarı-aşağı kayar
                    LazyVStack(spacing: 8){ // LazyVStack [SWIFT]: alt alta dizer, yalnız ekrandakileri çizer (uzun sohbette hızlı)
                        ForEach(messages){ message in // ForEach [SWIFT]: listedeki her mesaj için bir balon çizer | message: o anki mesaj
                            HStack{ // HStack [SWIFT]: yan yana dizer | Spacer ile balonu sağa ya da sola itiyoruz
                                if message.isMine {Spacer()} // isMine true (ben yazdım): önce boşluk, balon SAĞA yaslanır
                                Text(message.text) // mesajın yazısı
                                    .padding(10) // .padding [SWIFT]: yazının etrafında boşluk, balon dolgusu
                                    .background(message.isMine ? Color.blue : Color(.systemGray5))  // ?: kısa if | benim mesajım mavi, karşı tarafınki açık gri
                                    .foregroundColor(message.isMine ? .white : .primary) // yazı rengi | benimki beyaz, karşınınki sistem rengi (koyu/açık moda uyar)
                                    .clipShape(RoundedRectangle(cornerRadius: 16)) // köşeleri yuvarlar, balon şekli verir
                                
                                if !message.isMine {Spacer()} // ! = değil | karşı tarafın mesajı: balondan sonra boşluk, SOLA yaslanır
                            }
                            .id(message.id) // .id [SWIFT]: bu satıra "adres" verir | scrollTo ile en alttaki mesaja kaymak için gerekli
                            
                        }
                    }
                    .padding()
                }
                
                // .onChange [SWIFT]: bir değer değişince çalışır | messages.count: mesaj sayısı | yeni mesaj gelince (ya da ilk yüklemede) en alta kaydır
                .onChange(of: messages.count) {_, _ in
                    
                    if let last = messages.last {  // messages.last: son mesaj, liste boşsa nil | if let: nil değilse devam
                        proxy.scrollTo(last.id,anchor: .bottom) // son mesajın adresine kaydır | anchor: .bottom = ekranın altına hizala
                        
                    }
                    
                }
                
            }
            if let errorMessage {Text(errorMessage).foregroundColor(.red).font(.caption).padding(.horizontal)} // if let: doluysa kırmızı küçük yaz, nil ise çizilmez | gönderme/yükleme hatası burada çıkar
            
            if canWrite && !locked {  // yazma açıksa VE kilitlenmediyse alt çubuk çizilir (Pending ve Accepted teklifler)
                HStack{  // yan yana: yazma kutusu + Gönder düğmesi
                    TextField("Mesaj Yaz", text: $draft) // TextField [SWIFT]: yazı kutusu | $ = iki yönlü bağ, yazılan her harf draft'a gider
                        .textFieldStyle(.roundedBorder) // çerçeveli kutu görünümü
                    
                    Button("Gönder"){send()} // basınca aşağıdaki send() fonksiyonu çalışır
                        .buttonStyle(.borderedProminent) // içi dolu düğme
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty) // .disabled: koşul doğruysa basılamaz | trimmingCharacters: baş/son boşlukları siler | boş ya da yalnız boşluksa düğme kilitli
                }
                .padding()
            }else {
                Text("Bu sohbet kapalı (teklif reddedildi ya da iş tamamlandı). Eski mesajlar okunabilir.").font(.caption).foregroundColor(.secondary).padding() // yazma kutusu yerine bilgi yazısı | iki taraf da aynı mesajı görür // canWrite false: yazma kutusu yerine bilgi yazısı | eski mesajlar yine okunur
            }
            
        }
        .navigationTitle(title) // üst çubuk başlığı | dışarıdan gelen ilan adı
        .navigationBarTitleDisplayMode(.inline) // küçük , ortada başlık

        // ─── SAĞ ÜST MENÜ: iki ayrı işlem ───
        // Menu [SWIFT]: basınca seçenek listesi açan düğme | label: menüyü açan görünen kısım (üç nokta ikonu)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe
                Menu {
                    // 1) MESAJLARI TEMİZLE: yalnız mesajlar silinir, teklif ve iş yerinde kalır | yalnız KENDİ ekranımdan
                    Button("Mesajları Temizle", systemImage: "trash") { showClearConfirm = true } // systemImage: SF Symbols ikonu | basınca onay penceresi açılır
                    // 2) İŞİ BİTİR VE SİL: yalnız kabul edilmiş işte görünür | durum iki tarafta Tamamlandı olur, sohbet iki tarafta kilitlenir, benim tarafımdan teklif ve mesajlar silinir
                    if canComplete && !locked { // && ve | kabul edilmiş aktif iş ve henüz kilitlenmemişse
                        Button("İşi Bitir ve Sil", systemImage: "checkmark.seal", role: .destructive) { showCompleteConfirm = true } // role: .destructive: kırmızı
                    }
                } label: { Image(systemName: "ellipsis.circle") } // üç nokta ikonu
            }
        }
        // 1. onay penceresi: mesajları temizle | .confirmationDialog [SWIFT]: ekranın altından açılan seçenek menüsü | isPresented: $showClearConfirm → true olunca açılır
        .confirmationDialog("Mesajlar temizlensin mi?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Benden Sil", role: .destructive) { clearChat() } // seçilince aşağıdaki clearChat() çalışır
            Button("Vazgeç", role: .cancel) { } // pencereyi kapatır, hiçbir şey yapmaz
        } message: {
            Text("Mesajlar yalnızca sizin ekranınızdan silinir. Karşı taraf görmeye devam eder, iş ve teklif yerinde kalır.")
        }
        // 2. onay penceresi: işi bitir | .alert [SWIFT]: ekranın ortasında çıkan uyarı penceresi | daha önemli işlemler için (bitirmek iki tarafı etkiler)
        .alert("İş bitsin mi?", isPresented: $showCompleteConfirm) {
            Button("Bitir ve Sil", role: .destructive) { completeJob() } // seçilince aşağıdaki completeJob() çalışır
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("İş iki tarafta da Tamamlandı olur ve sohbet iki tarafta yazmaya kapanır. Teklif ve mesajlar sizin listenizden silinir; karşı taraf tamamlanmış işi kendi geçmişinde görür.")
        }
        
        //YENİLEME DÖNGÜSÜ | .task [SWIFT]: ekran açılınca başlar, ekran kapanınca KENDİLİĞİNDEN iptal olur
        // while !Task.isCancelled: iptal edilene kadar tekrarla | Task.sleep: 3 sn bekle | canlı bağlantı (SignalR) yerine basit yöntem: kısa aralıkla yeniden sor
        .task{ // ekran açılınca bir kez başlar; içindeki while kendisi tekrar eder
            while !Task.isCancelled { // ekran açık olduğu sürece döner
                await loadMessages() // mesajları apide cek
                try? await Task.sleep(for: .seconds(3)) // 3 saniye bekle | try?: ekran kapanıp iptal olursa hata fırlatır, sessizce geç (try? = hata olursa yok say)
            }
        }
        
    }
    
    // loadMessages: mesajları API'den çekip @State'e yazar | private: yalnız bu ekran görür | async: içinde await var
    // ÇAĞIRAN: yukarıdaki .task döngüsü (3 sn'de bir) ve send() sonrası
    
    private func loadMessages() async {
        do {  // do: dene | hata olursa catch'lerden biri çalışır
            messages = try await ChatService().messages(offerId: offerId) // BAĞLANTI: Network/ChatService.swift → GET /api/v1/offers/{offerId}/messages | dönen liste @State'e yazılır, ekran yenilenir
          
        }catch let error as AuthError{ // API hayır dedi (401, 404...) | AuthError: Network/AuthService.swift
            errorMessage = error.message
            
        } catch { // başka her hata: API kapalı, internet yok
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { return } // İPTAL ≠ HATA: SwiftUI ekran yenilenirken/çıkılırken çalışan .task'ı iptal eder, o işin internet isteği "cancelled" hatası fırlatır | bunu kullanıcıya "Sunucuya ulaşılamadı." diye göstermeyiz | Task.isCancelled: bu iş iptal edildi mi | (error as? URLError): hata internet hatası türüne çevrilebiliyorsa | .code == .cancelled: sebebi iptal | return: sessizce çık
            errorMessage = "Sunucuya Ulaşılamadı"
        }
    }
    // send: Gönder düğmesi | yazılan metni API'ye yollar, sonra mesajları yeniden çeker | ÇAĞIRAN: yukarıdaki Gönder düğmesi
    
    private func send(){
        let text = draft.trimmingCharacters(in: .whitespaces)  // baş/son boşlukları temizle
        guard !text.isEmpty else { return } // guard: boşsa dur (düğme zaten kilitli, ikinci güvenlik) | return: çık
        draft = "" // kutuyu hemen boşalt, kullanıcı beklemeden yeni mesaj yazabilir
        
        Task{  // Task [SWIFT]: normal fonksiyon (async değil) içinde await kullanmamızı sağlar
            errorMessage = nil // eski hatayı izle
            
            do {
            // BAĞLANTI: Network/ChatService.swift → POST /api/v1/offers/{offerId}/messages | paket kalıbı: SendMessageRequest
                try await ChatService().send(offerId: offerId, SendMessageRequest(text: text))
                await loadMessages() // gönderildi, 3 sn beklemeden listeyi hemen yenile: kendi mesajım balon olarak görünür
                
            }catch let error as AuthError{
                errorMessage = error.message // örn. "Reddedilen teklifte sohbet kapalı."
                draft = text // gönderilemedi, yazdığı metin kaybolmasın, kutuya geri koy
                if error.message.contains("kapalı") { locked = true } // sunucu "sohbet kapalı" dediyse (karşı taraf işi bitirdi / teklif reddedildi) yazma kutusunu hemen kapat | .contains: yazının içinde geçiyor mu
            }catch{
                errorMessage = "Sunucuya Ulaşılamadı"
                draft = text
            }
        }
    }
    
    

    // clearChat: onay penceresinde "Benden Sil" seçilince çalışır | mesajları yalnız kendi görünümümden siler (karşı taraf etkilenmez)
    // ÇAĞIRAN: yukarıdaki 1. onay penceresi
    private func clearChat() {
        Task { // Task [SWIFT]: normal fonksiyon içinde await kullanmamızı sağlar
            errorMessage = nil // eski hatayı temizle
            do {
                try await ChatService().clear(offerId: offerId) // BAĞLANTI: Network/ChatService.swift → clear → DELETE /api/v1/offers/{id}/messages
                await loadMessages() // silindi, listeyi hemen yeniden çek: sunucu bu kullanıcı için mesajları gizlediğinden liste boş gelir
            } catch let error as AuthError {
                errorMessage = error.message
            } catch {
                errorMessage = "Sunucuya ulaşılamadı."
            }
        }
    }

    // completeJob: 2. onay penceresinde "Bitir ve Sil" seçilince çalışır | işi tamamlar
    // ÇAĞIRAN: yukarıdaki .alert | BAĞLANTI: Network/ChatService.swift → complete → POST /api/v1/offers/{id}/complete
    private func completeJob() {
        Task {
            errorMessage = nil
            do {
                try await ChatService().complete(offerId: offerId) // sunucuda teklif iki tarafta Tamamlandı olur, bizim listemizden silinir
                dismiss() // artık bu teklif listemizde yok, sohbetten geri dön | önceki ekran görününce .task ile listeyi kendisi yeniler
            } catch let error as AuthError {
                errorMessage = error.message // örn. "Yalnız kabul edilmiş iş tamamlanabilir."
            } catch {
                errorMessage = "Sunucuya ulaşılamadı."
            }
        }
    }
}
