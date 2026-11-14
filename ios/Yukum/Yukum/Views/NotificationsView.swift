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
    @Environment(\.colorScheme) private var colorScheme

    // GÖRÜNÜM (15 Kasım, L tasarım): yarı şeffaf kartlar; okunmamış kart turuncu kenarlı + turuncu nokta. İŞLEV DEĞİŞMEDİ.
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        List {
            if let message = viewModel.errorMessage {
                FormMessage(text: message, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(viewModel.items) { item in
                Button { Task { await viewModel.markRead(item) } } label: { row(item, palette) } // dokununca okundu
                    .buttonStyle(.plain)
                    .themedRow()
                    .overlay { if !item.isRead { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.accent.opacity(0.55)).padding(.horizontal, 16).padding(.vertical, 5) } }
                    .swipeActions {
                        Button(role: .destructive) { Task { await viewModel.delete(item) } } label: { Label("Sil", systemImage: "trash") }
                    }
                    .task { if item.id == viewModel.items.last?.id { await viewModel.loadMore() } } // son kart görününce sonraki sayfa
            }
            if viewModel.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .overlay {
            if viewModel.items.isEmpty && viewModel.isLoading {
                LoadingCard().padding() // ilk yükleme: "Bildirim yok" veri gelmeden çıkmasın
            } else if viewModel.items.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                EmptyStateCard(icon: "bell.slash", title: "Bildirim yok", detail: "Teklif, kabul ve iş güncellemeleri burada görünür.").padding()
            }
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Tümünü oku") { Task { await viewModel.markAllRead() } }.disabled(!viewModel.hasUnread)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(_ item: AppNotification, _ palette: Palette) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: item.type))
                .font(.subheadline.bold()).foregroundStyle(palette.accent)
                .frame(width: 34, height: 34).background(palette.accent.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline).fontWeight(item.isRead ? .regular : .bold).foregroundStyle(palette.title)
                Text(item.body).font(.footnote).foregroundStyle(palette.label.opacity(0.75))
                if let date = item.createdDate {
                    Text(date, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(palette.label.opacity(0.6)) // "5 dk önce"
                }
            }
            Spacer()
            if !item.isRead { Circle().fill(palette.accent).frame(width: 9, height: 9) }
        }
        .contentShape(Rectangle()) // boşluklara dokununca da çalışsın
    }

    private func icon(for type: String) -> String {
        switch type {
        case "OfferReceived": "tray.and.arrow.down.fill"
        case "OfferAccepted": "checkmark.circle.fill"
        case "OfferRejected": "xmark.circle.fill"
        case "JobStageChanged": "truck.box.fill"
        case "JobCompleted": "flag.checkered"
        case "ReviewReceived": "star.fill"
        case "ListingCancelled": "trash.fill"
        case "CancelRequested": "exclamationmark.bubble.fill" // karşılıklı iptal talebi (15 Kasım)
        case "CancelApproved": "hand.raised.fill"
        case "CancelRejected": "arrow.uturn.backward.circle.fill"
        default: "bell.fill"
        }
    }
}

#Preview { NavigationStack { NotificationsView() } }
