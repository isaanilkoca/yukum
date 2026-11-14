//
//  PrivacyView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 11.11.2026.
//

import SwiftUI


// ┌─ BAĞLANTI HARİTASI: PrivacyView ──────────────────────────────────────────────────
// │ VIEWMODEL : yok (sabit metin, veri çekmez) | açan: Views/HomeView "Gizlilik ve KVKK", RegisterView / CarrierRegisterView "Metni oku" (.sheet)


struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss // bu sayfayı kapatır swift
    
    
    
var body: some View {
    
    NavigationStack{
        ScrollView{
            VStack(alignment: .leading, spacing: 20){
                block("Hangi bilgileri topluyoruz?",
                                          "Ad soyad, e-posta, telefon ve şifren (şifre yalnız geri döndürülemez özet olarak saklanır). Yük Veren isen isteğe bağlı firma ve vergi bilgisi; Taşımacı isen çalıştığın iller ve araç bilgilerin (tip, kapasite, plaka). Uygulamayı kullanırken oluşturduğun ilanlar, teklifler, sohbet mesajları, puan ve yorumlar, favoriler.")
                                    block("Ne için kullanıyoruz?",
                                          "Yalnız uygulamanın çalışması için: giriş yapman, ilan ve teklifleri eşleştirmen, karşı tarafla yazışman ve puan verebilmen. Bilgilerini reklam için kullanmaz, üçüncü kişilere satmayız.")
                                    block("Konumun",
                                          "Yakınımdaki ilanları sıralamak için konum izni istenir. Konumun yalnız o sorgu için sunucuya gönderilir, saklanmaz. İzni vermesen de uygulama çalışır.")
                                    block("Karşı tarafa ne görünür?",
                                          "İlan ve tekliflerde adın, yorumlarda kısaltılmış adın (Ali V. gibi) görünür. Telefon ve e-postan karşı tarafa gösterilmez.")
                                    block("Hesabını silersen",
                                          "Ad, e-posta, telefon, şifre, firma ve plaka bilgilerin geri döndürülemez biçimde silinir; hesap \"Silinmiş Kullanıcı\" olarak kalır. Açık ilanların kaldırılır, bekleyen tekliflerin iptal olur, favorilerin silinir. Tamamlanmış işler ve puanlar karşı tarafın geçmişi olduğu için adın gizlenerek durur. Devam eden bir işin varken hesap silinemez.")
                                    block("Haklarının kullanımı",
                                          "KVKK kapsamında bilgilerine erişme, düzeltme ve silme hakkın vardır. Silme işlemini uygulamada Ana sayfa › Hesabı Sil ile kendin yapabilirsin.")
                                    // ATIF (14 Kasım): Yük Veren ana ekranındaki dorse hazır bir 3B modelden (Design/Truck.usdz, CC-BY 4.0).
                                    //   Lisans, kaynağın adının uygulamada geçmesini şart koşar → ana ekrandan buraya taşındı (kullanıcı ana ekranda istemedi).
                                    block("Atıflar",
                                          "Ana ekrandaki 3B dorse modeli: \"Truck\" by ROY (Sketchfab), CC-BY 4.0 lisansıyla kullanılmıştır.")
            }
            .padding()
        }
        .navigationTitle("Gizlilik ve KVKK")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) { Button("Kapat"){dismiss()}}
        }
    }
        
        
}
    // block: "başlık + açıklama" kalıbı | private func [SWIFT]: yalnız bu dosyada kullanılır | -> some View: bir görünüm döndürür | _ : çağırırken etiket yazılmaz
      private func block(_ title: String, _ text: String) -> some View {
          VStack(alignment: .leading, spacing: 6) {
              Text(title).font(.headline) // kalın başlık
              Text(text).font(.subheadline).foregroundColor(.secondary) // gri açıklama
          }
      }
}

#Preview { PrivacyView() } // #Preview [SWIFT]: Xcode sağ panelinde canlı önizleme
