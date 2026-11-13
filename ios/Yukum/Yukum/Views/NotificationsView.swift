//
//  NotificationsView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 12.11.2026.
//

import SwiftUI

// ┌─ BAĞLANTI HARİTASI: NotificationsView ───────────────────────────────────────────
// │ VIEWMODEL : ViewModels/NotificationsViewModel | açan: Views/HomeView sağ üst zil (NavigationLink)
// │ Ekran açılınca / aşağı çekince →  viewModel.load()        →  GET /api/v1/notifications?page=1
// │ Son satır görününce            →  viewModel.loadMore()    →  GET /api/v1/notifications?page=2...
// │ Satıra basınca                 →  viewModel.markRead()    →  POST /api/v1/notifications/{id}/read
// │ "Tümünü oku"                   →  viewModel.markAllRead() →  POST /api/v1/notifications/read-all
// │ Satırı sola kaydır → "Sil"     →  viewModel.delete()      →  DELETE /api/v1/notifications/{id}

struct NotificationsView: View {
    
    @State private var viewModel = NotificationsViewModel()
    
    var body: some View {
        
        List { // List [SWIFT]: kaydırılabilir satır listesi
            if let message = viewModel.errorMessage {
                Text(message).foregroundColor(.red)
            }
            ForEach(viewModel.items) { item in // AppNotification Identifiable olduğu için id: yazılmaz
                Button { // satırın tamamı düğme: basınca okundu olur
                    Task { await viewModel.markRead(item) }
                } label: {
                    row(item)
                }
                .buttonStyle(.plain) // .plain [SWIFT]: düğme görünümü yok (yazılar maviye dönmesin)
                // .swipeActions [SWIFT]: satır sola kaydırılınca çıkan düğmeler | yalnız List içindeki satırda çalışır
                // role: .destructive [SWIFT]: "yıkıcı işlem" → düğme kırmızı olur, satır kaybolurken silme animasyonu oynar
                // Tam kaydırma (sonuna kadar çekme) ilk düğmeyi kendiliğinden çalıştırır: Mail'deki davranış (allowsFullSwipe varsayılanı true)
                // Onay sorulmuyor: bildirim iş kaydı değil; teklif/iş yerinde durur, yalnız haberi silinir
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(item) }
                    } label: {
                        Label("Sil", systemImage: "trash") // Label [SWIFT]: yazı + ikon birlikte
                    }
                }
                .task { // .task [SWIFT]: bu satır ekrana gelince çalışır
                    if item.id == viewModel.items.last?.id { await viewModel.loadMore() } // son satır göründü → sonraki sayfa | last? : liste boşsa nil
                }
            }
            if viewModel.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity) // dönen yükleniyor göstergesi, ortada
            }
        }
        .overlay { // .overlay [SWIFT]: listenin üstüne çizer | liste boşken boş durum yazısı
            if viewModel.items.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                ContentUnavailableView("Bildirim yok", systemImage: "bell.slash", description: Text("Teklif, kabul ve iş güncellemeleri burada görünür.")) // [SWIFT] hazır boş durum görünümü
            }
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Tümünü oku") { Task { await viewModel.markAllRead() } }
                    .disabled(!viewModel.hasUnread) // okunmamış yoksa basılamaz
            }
        }
        .task { await viewModel.load() } // ekran açılınca ilk sayfa
        .refreshable { await viewModel.load() } // aşağı çekince yenile
    }

    // row: tek satırın görünümü | ikon + (başlık, metin, zaman) + okunmamış noktası
    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) { // HStack [SWIFT]: yan yana dizer
            Image(systemName: icon(for: item.type)) // SF Symbols ikonu
                .foregroundColor(.accentColor)
                .frame(width: 24) // ikonlar aynı hizada dursun
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline).fontWeight(item.isRead ? .regular : .bold) // okunmamış kalın
                Text(item.body).font(.footnote).foregroundColor(.secondary)
                if let date = item.createdDate {
                    // .relative [SWIFT]: "2 saat önce", "dün" | telefonun diline uyar
                    Text(date, format: .relative(presentation: .named)).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer() // Spacer [SWIFT]: aradaki boşluğu doldurur, noktayı sağa iter
            if !item.isRead {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8) // okunmamış: mavi nokta
            }
        }
        .contentShape(Rectangle()) // satırın boş yerine basınca da tıklama algılansın
    }

    // icon: bildirim türüne göre ikon adı | default: bilinmeyen (ileride eklenecek) tür için zil
    private func icon(for type: String) -> String {
           switch type {
           case "OfferReceived": "tray.and.arrow.down"
           case "OfferAccepted": "checkmark.circle"
           case "OfferRejected": "xmark.circle"
           case "JobStageChanged": "shippingbox"
           case "JobCompleted": "flag.checkered"
           case "ReviewReceived": "star"
           case "ListingCancelled": "trash"
           default: "bell"
           }
       }
}


#Preview { NavigationStack { NotificationsView() } } // önizlemede üst çubuk görünsün diye NavigationStack içinde
