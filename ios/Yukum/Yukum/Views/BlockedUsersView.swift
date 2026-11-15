//
//  BlockedUsersView.swift
//  Yukum
//
//  Profil → Engellediklerim (15 Kasım): engellediğim kişiler, sola kaydır → Engeli Kaldır.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: BlockedUsersView ─────────────────────────────────────────
// │ AÇAN      : Views/ProfileView "Engellediklerim" (iki rol)
// │ VIEWMODEL : ViewModels/BlockedUsersViewModel → GET /api/v1/account/blocks · DELETE /api/v1/users/{id}/block
// │ ANİMASYON : engel kaldırma olumlu → rolün animasyonu (Yük Veren .seal, Taşımacı .track)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [BlockedUsersView]: ProfileView
struct BlockedUsersView: View {
    let isShipper: Bool
    @State private var viewModel = BlockedUsersViewModel()
    @State private var feedback: ActionFeedback?
    @State private var busy = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        List {
            if let message = viewModel.errorMessage {
                FormMessage(text: message, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if viewModel.users.isEmpty && !viewModel.isLoading {
                EmptyStateCard(icon: "hand.raised", title: "Engellediğin kimse yok.",
                               detail: "Sohbet, profil ya da ilan ekranındaki ⋯ menüsünden engelleyebilirsin.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(viewModel.users) { user in
                HStack(spacing: 12) {
                    AvatarView(url: nil, name: user.fullName, size: 40) // ⮕ Design/AvatarView.swift (fotoğraf gelmez: baş harfler)
                    Text(user.fullName).font(.body.weight(.semibold)).foregroundStyle(palette.title)
                    Spacer()
                    Button("Kaldır") { Task { await unblock(user) } }.buttonStyle(ChipButtonStyle(.outline))
                }
                .themedRow()
                .swipeActions { Button("Engeli Kaldır") { Task { await unblock(user) } }.tint(palette.accent) }
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .busyIndicator(busy)
        .navigationTitle("Engellediklerim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .actionFeedback($feedback)
    }

    private func unblock(_ user: BlockedUser) async {
        busy = true; defer { busy = false }
        if await viewModel.unblock(user) { feedback = ActionFeedback(isShipper ? .seal : .track, "Engel kaldırıldı") } // ⮕ BlockedUsersViewModel.unblock
    }
}
