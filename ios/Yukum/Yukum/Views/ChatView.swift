//
//  ChatView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ChatView (sohbet) ─────────────────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Mesaj balonları          →  viewModel.messages ← load()         →  ChatService.messages()          →  GET /api/v1/offers/{id}/messages →  [ChatMessage]
// │ Yazma kutusu             →  viewModel.draft ($ bağ)             →  (yazılır, send() okur)          →  -                                →  -
// │ Gönder düğmesi           →  viewModel.send()                    →  ChatService.send()              →  POST /api/v1/offers/{id}/messages →  SendMessageRequest
// │ Menü: Mesajları Temizle  →  viewModel.clear()                   →  ChatService.clear()             →  DELETE .../messages              →  (yok)
// │ Menü: İşi Bitir ve Sil   →  viewModel.complete()                →  ChatService.complete()          →  POST /api/v1/offers/{id}/complete →  (yok)
// │ Yazma/menü kuralları     →  viewModel.canWrite, canComplete, canSend, locked  (kural: ChatContext + locked)
// │ Otomatik yenileme        →  .task { startPolling() } → 3 sn'de bir load()  (ekran kapanınca iptal)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: bir teklifin sohbeti. Yük Veren ile teklifi veren Taşımacı yazışır. Mesajlar balon olarak çizilir, ekran açıkken 3 sn'de bir yenilenir.
// MVVM: bu dosya yalnız GÖRÜNÜM. Mesajlar, taslak, gönderme, temizleme, işi bitirme, kilit ve yenileme döngüsü ViewModels/ChatViewModel.swift'te.
// BAĞLANTI: Views/ListingOffersView.swift (Yük Veren), Views/MyOffersView.swift (Taşımacı), Views/OldOffersView.swift (Yük Veren geçmişi) "Sohbet" düğmesiyle bu ekranı açar
//
// SOHBET MANTIĞI (4 adım):
//   1) EKRAN AÇILINCA  → mesajları API'den çek (GET)
//   2) GÖNDERİNCE      → yazıyı API'ye yolla (POST), sonra listeyi yeniden çek
//   3) KARŞI TARAFIN MESAJI → sunucu "push" yapmaz; ViewModel 3 sn'de bir tekrar sorar (polling) | canlı bağlantı yok, basit yöntem
//   4) ÇİZİM           → her mesaj isMine'a bakılıp sağa (benim) ya da sola (karşı taraf) yaslı balon olur

// ⮕ KULLANIM [ChatView]: kullanır: ListingOffersView › body, MyOffersView › body, OldOffersView › body
struct ChatView: View {

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    // ⮕ KULLANIM [viewModel]: okur: ChatView › body | bağlar(okur+yazar): ChatView › body
    @State private var viewModel: ChatViewModel // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    // ⮕ KULLANIM [dismiss]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer | dismiss: "bu ekranı kapat" komutu | iş bitirilince sohbetten geri dönmek için

    // Onay pencerelerinin açık/kapalı durumu: yalnız GÖRÜNÜM bilgisi (hangi pencere açık), iş mantığı değil, bu yüzden ViewModel'de değil burada
    // showClearConfirm: "Mesajları Temizle" onay penceresi | NEDEN onay: silme geri alınamaz, yanlışlıkla basılmasın
    // ⮕ KULLANIM [showClearConfirm]: YAZAR: ChatView › body | bağlar(okur+yazar): ChatView › body
    @State private var showClearConfirm = false
    // showCompleteConfirm: "İşi Bitir ve Sil" onay penceresi | bu işlem daha ağır (iki tarafta durumu değiştirir), ayrı ve daha açıklayıcı bir pencereyle sorulur
    // ⮕ KULLANIM [showCompleteConfirm]: YAZAR: ChatView › body | bağlar(okur+yazar): ChatView › body
    @State private var showCompleteConfirm = false

    // init: açılış bilgisi (ChatContext) dışarıdan verilir, ViewModel burada oluşturulur
    init(context: ChatContext) {
        _viewModel = State(initialValue: ChatViewModel(context: context))
    }

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {

        // @Bindable [SWIFT]: @Observable bir sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField doğrudan ViewModel'deki taslağa yazsın diye)
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            ScrollViewReader { proxy in // ScrollViewReader [SWIFT]: kaydırmayı KODLA yönetmeye yarar | proxy: kaydırma kumandası | yeni mesaj gelince en alta inmek için
                ScrollView { // ScrollView [SWIFT]: kaydırılabilir alan | mesajlar ekrana sığmayınca yukarı-aşağı kayar
                    LazyVStack(spacing: 8) { // LazyVStack [SWIFT]: alt alta dizer, yalnız ekrandakileri çizer (uzun sohbette hızlı)
                        ForEach(viewModel.messages) { message in // ForEach [SWIFT]: listedeki her mesaj için bir balon çizer | message: o anki mesaj | ⮕ ChatViewModel.messages ← ChatService.messages() → [ChatMessage]
                            HStack { // HStack [SWIFT]: yan yana dizer | Spacer ile balonu sağa ya da sola itiyoruz
                                if message.isMine { Spacer() } // isMine true (ben yazdım): önce boşluk, balon SAĞA yaslanır
                                Text(message.text) // mesajın yazısı
                                    .padding(10) // .padding [SWIFT]: yazının etrafında boşluk, balon dolgusu
                                    .background(message.isMine ? Color.blue : Color(.systemGray5)) // ?: kısa if | benim mesajım mavi, karşı tarafınki açık gri | Color [SWIFT]: renk | .background [SWIFT]: arka plan
                                    .foregroundColor(message.isMine ? .white : .primary) // yazı rengi | benimki beyaz, karşınınki sistem rengi (koyu/açık moda uyar) | .foregroundColor [SWIFT]: yazı rengi
                                    .clipShape(RoundedRectangle(cornerRadius: 16)) // köşeleri yuvarlar, balon şekli verir | RoundedRectangle [SWIFT]: köşeleri yuvarlak dikdörtgen | .clipShape [SWIFT]: görünümü şekle göre keser

                                if !message.isMine { Spacer() } // ! = değil | karşı tarafın mesajı: balondan sonra boşluk, SOLA yaslanır
                            }
                            .id(message.id) // .id [SWIFT]: bu satıra "adres" verir | scrollTo ile en alttaki mesaja kaymak için gerekli
                        }
                    }
                    .padding()
                }

                // .onChange [SWIFT]: bir değer değişince çalışır | mesaj sayısı değişince (yeni mesaj ya da ilk yükleme) en alta kaydır
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last { // last: son mesaj, liste boşsa nil | if let: nil değilse devam
                        proxy.scrollTo(last.id, anchor: .bottom) // son mesajın adresine kaydır | anchor: .bottom = ekranın altına hizala
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red).font(.caption).padding(.horizontal) } // if let: doluysa kırmızı küçük yaz, nil ise çizilmez | gönderme/yükleme hatası burada çıkar | .font [SWIFT]: yazı boyutu/stili

            if viewModel.canWrite { // yazma açıksa (Pending ve Accepted teklifler) VE kilitlenmediyse alt çubuk çizilir
                HStack { // yan yana: yazma kutusu + Gönder düğmesi
                    TextField("Mesaj Yaz", text: $viewModel.draft) // TextField [SWIFT]: yazı kutusu | $ = iki yönlü bağ, yazılan her harf ViewModel'deki draft'a gider | ⮕ ChatViewModel.draft
                        .textFieldStyle(.roundedBorder) // çerçeveli kutu görünümü | .textFieldStyle [SWIFT]: yazı kutusu stili

                    Button("Gönder") { Task { await viewModel.send() } } // basınca ViewModel mesajı yollar | Task [SWIFT]: düğmede await kullanmamızı sağlar | ⮕ ChatViewModel.send() → ChatService.send(SendMessageRequest) | Button [SWIFT]: dokununca kod çalıştıran düğme
                        .buttonStyle(.borderedProminent) // içi dolu düğme | .buttonStyle [SWIFT]: düğme görünüm stili
                        .disabled(!viewModel.canSend) // .disabled: koşul doğruysa basılamaz | boş ya da yalnız boşluksa düğme kilitli | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli
                }
                .padding()
            } else {
                Text("Bu sohbet kapalı (teklif reddedildi ya da iş tamamlandı). Eski mesajlar okunabilir.").font(.caption).foregroundColor(.secondary).padding() // yazma kutusu yerine bilgi yazısı | iki taraf da aynı mesajı görür
            }
        }
        .navigationTitle(viewModel.context.title) // üst çubuk başlığı | karşı tarafın adı | .navigationTitle [SWIFT]: üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline) // küçük, ortada başlık | .navigationBarTitleDisplayMode [SWIFT]: üst başlığın boyut biçimi

        // ─── SAĞ ÜST MENÜ: iki ayrı işlem ───
        // Menu [SWIFT]: basınca seçenek listesi açan düğme | label: menüyü açan görünen kısım (üç nokta ikonu)
        .toolbar { // .toolbar [SWIFT]: üst çubuğa eleman koyar
            ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe | ToolbarItem [SWIFT]: üst çubukta bir eleman
                Menu {
                    // 1) MESAJLARI TEMİZLE: yalnız mesajlar silinir, teklif ve iş yerinde kalır | yalnız KENDİ ekranımdan
                    Button("Mesajları Temizle", systemImage: "trash") { showClearConfirm = true } // systemImage: SF Symbols ikonu | basınca onay penceresi açılır
                    // 2) İŞİ BİTİR VE SİL: yalnız kabul edilmiş işte görünür | durum iki tarafta Tamamlandı olur, sohbet iki tarafta kilitlenir, benim tarafımdan teklif ve mesajlar silinir
                    if viewModel.canComplete { // kabul edilmiş aktif iş ve henüz kilitlenmemişse
                        Button("İşi Bitir ve Sil", systemImage: "checkmark.seal", role: .destructive) { showCompleteConfirm = true } // role: .destructive: kırmızı
                    }
                } label: { Image(systemName: "ellipsis.circle") } // üç nokta ikonu | Image [SWIFT]: görsel/ikon (systemName: SF Symbols hazır ikonları)
            }
        }
        // 1. onay penceresi: mesajları temizle | .confirmationDialog [SWIFT]: ekranın altından açılan seçenek menüsü | isPresented: $showClearConfirm → true olunca açılır
        .confirmationDialog("Mesajlar temizlensin mi?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Benden Sil", role: .destructive) { Task { await viewModel.clear() } } // seçilince ViewModel temizler | ⮕ ChatViewModel.clear() → ChatService.clear
            Button("Vazgeç", role: .cancel) { } // pencereyi kapatır, hiçbir şey yapmaz
        } message: {
            Text("Mesajlar yalnızca sizin ekranınızdan silinir. Karşı taraf görmeye devam eder, iş ve teklif yerinde kalır.")
        }
        // 2. onay penceresi: işi bitir | .alert [SWIFT]: ekranın ortasında çıkan uyarı penceresi | daha önemli işlemler için (bitirmek iki tarafı etkiler)
        .alert("İş bitsin mi?", isPresented: $showCompleteConfirm) {
            Button("Bitir ve Sil", role: .destructive) { // seçilince ViewModel işi tamamlar; başarılıysa teklif listemizden silindiği için sohbetten geri dönülür
                Task { if await viewModel.complete() { dismiss() } } // önceki ekran görününce .task ile listeyi kendisi yeniler | ⮕ ChatViewModel.complete() → ChatService.complete
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("İş iki tarafta da Tamamlandı olur ve sohbet iki tarafta yazmaya kapanır. Teklif ve mesajlar sizin listenizden silinir; karşı taraf tamamlanmış işi kendi geçmişinde görür.")
        }

        // .task [SWIFT]: ekran açılınca başlar, ekran kapanınca KENDİLİĞİNDEN iptal olur | ViewModel'in yenileme döngüsü (polling) burada çalışır
        .task { await viewModel.startPolling() } // ⮕ ChatViewModel.startPolling() → 3 sn'de bir load() → ChatService.messages
    }
}
