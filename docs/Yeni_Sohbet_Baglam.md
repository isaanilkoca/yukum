# Yüküm – Yeni Sohbet Bağlam Dosyası (Sürüm 2)

Bu dosyayı yeni bir sohbete (veya Claude Code oturumuna) ilk mesaj olarak ver. İki PDF raporun özeti ve çalışma kurallarıdır.
Ayrıntı: `Yukum_Teknik_Rapor.pdf` (ne & neden; Giriş → Backend (5–8) → Veritabanı (9) → iOS (10–12) → Algoritma/mantık (13) → Güvenlik/Test (14–15) → Teknoloji gerekçesi + mülakat (16–18) → Sonuç (19–22); başında “Ne nerede?” haritası var) ve `Yukum_Adim_Adim_Uygulama_Plani.pdf` (yapım sırası Bölüm 2–3, birleştirme/bağlama Bölüm 4–5, notlar→adımlar eşleşmesi Bölüm 6).

## Proje ve amaç
Yüküm: yük sahibinin (Yük Veren) ilan açtığı, taşımacının (Carrier) ilana **fiyat teklifi** verdiği açık pazar mobil uygulaması (Mersin tarım ilacı taşıma deneyiminden doğdu; taşımacı dönüşte boş dönmesin).
**Asıl amaç:** İş mülakatında "iOS'çuyum ama backend'i ve veritabanını da güncel/piyasada rağbet gören teknolojilerle kurdum" diyebilmek için **vitrin proje**.

## Kesin kararlar
- İlanı **yalnız Yük Veren** açar; teklifi **yalnız Taşımacı** verir. Admin ayrı rol; normal kullanıcı admin alanına giremez.
- **KAPSAM KURALI:** Yalnızca notlardaki özellikler yapılır. Kendi başına özellik ekleme (mesajlaşma, ödeme, belge doğrulama, dönüş rotası, harita, admin web paneli vb. YOK). Eklemeye izin olan tek yer: "güncel teknoloji" seçimleri — onlar da araştırmayla.
- Backend: **.NET 10 (LTS)**, ASP.NET Core Web API (controller), **EF Core 10 + Repository Pattern (+UoW)**, **MSSQL**, Clean Architecture (Domain/Application/Infrastructure/Api) + **CQRS-lite** (Command/Query handler sınıfları). **MediatR ve AutoMapper kullanılmaz** (ticari lisansa geçtiler); mapping elle/Mapster. API dokümantasyonu: yerleşik **OpenAPI + Scalar**. Docker Compose (API+SQL Server), GitHub Actions CI, Serilog + OpenTelemetry + Health Checks, xUnit + Testcontainers. VS Code.
- Kimlik: ASP.NET Identity + JWT (10–15 dk) + rotasyonlu refresh token (hash'li), RBAC/policy + **sahiplik kontrolü** (IDOR).
- iOS: **Swift 6.2, Xcode 26 (iOS 26 SDK), SwiftUI, MVVM + Router (NavigationStack) + protokol DI, async/await, actor, @Observable, URLSession, Keychain, min iOS 18** (öneri; alternatif 17). Swift Testing + XCUITest. VIPER/TCA **uygulanmaz, mülakat için anlatılır**. Kullanıcı iOS'u **kendisi yazar**.
- **Generic APIClient**: tek `send<Response: Decodable>(endpoint, body)` metodu; Endpoint soyutlaması; 401'de actor ile tek refresh.
- **Auto-login**: Keychain'de refresh token → açılışta yenile → rol bazlı ana ekran. Ağ yoksa oturum silinmez.
- İl/ilçe: `Cities`/`Districts` seed tabloları + `GET /cities`, `GET /cities/{id}/districts`.
- JSON: camelCase, UTC ISO8601, enum string, GUID string, ProblemDetails, `/api/v1`.

## Çalışma kuralları
1. **Kod yazmadan önce mantık anlatılır**, kullanıcı onaylar; "hepsini yapıştır-yap" yok. Backend + DB birlikte; iOS'u kullanıcı yazar.
2. **Tek seferde tek dilim**: DB → Repository → Servis/Handler → Controller → Scalar testi → test → iOS Endpoint/Model → ViewModel → View → Git commit. Kabul kriteri sağlanmadan sonraki adım yok.
3. **Küçükten büyüğe**: A Hazırlık → B Backend temeli (+Docker/CI) → C İl/ilçe + ilk iOS bağlantısı → D Kimlik → E İlan → F Teklif (**MVP**) → G İş/puan/profil → H Favori/sayaç → I Bildirim → J Konum + emsal fiyat → K Sertleştirme/yayın → L Süsleme.
4. **Hedef önce ilk çalışır hâl (Aşama A–F).** Tasarım, ek özellik, Docker/CI/OpenTelemetry, bildirim, konum vb. ilk çalışır hâlden sonra tek tek eklenir. Kesin olmayan kararlar yol ilerledikçe ilgili adımda birlikte verilir. Önce çalıştır, sonra süsle. Konuşarak ilerle; açık kararları ilgili adımdan önce sor.

## Kapsam (notlardan)
Login/Register(2 tip) • İlan verme (il→ilçe) • İlan listeleme • Filtre/sıralama (fiyat, **varış şehri**, emsal fiyat, konum — konum öncelik değil) • "Bana yakın X km" • Favori • İlan sonrası mail/push • Görüntülenme/teklif sayacı (görme öncelikli) • Fiyat teklifi verme • Profilde anlaşılan işler (iki tarafta) • Push (beğeni, teklif) • İlan detayında sahibe veriler • Teslim sonrası yük veren taşımacıyı puanlar/yorumlar • Puana göre öne çıkarma • Taşımacı profili (ort. puan+yorumlar) • Opsiyonel (sonra): AI ile yasaklı içerik kontrolü • Android/Web aynı API'yi kullanabilir.
(App Store'a yayın yapılırsa Apple gereği şikâyet/engelleme/hesap silme — yalnız o zaman.)

## Açık kararlar
Q2 teklifler diğer taşımacılara görünür mü • Q3 bütçe fiyatı zorunlu mu • Q4 karşı teklif var mı • Q5 telefon ne zaman paylaşılır • Q8 anlaşma sonrası iptal • Q9 yük cinsi kısıtları • Q11 dil • Q12 min iOS (18 mi 17 mi) • Q13 yalnız MVVM mi, bir modülde VIPER de denensin mi.

## Durum
Rapor aşaması tamam (Sürüm 2). **Sıradaki:** A1 (kurulum kontrolü: .NET 10 SDK, VS Code C# Dev Kit, Docker+SQL Server 2022, Git, Xcode 26) ve A4 (tasarım kararları: renk/font), sonra B1 (backend solution iskeleti).

## Yeni sohbette ilk mesaj önerisi
> `Yeni_Sohbet_Baglam.md` ve iki PDF'i oku. Çalışma kurallarına ve kapsam kuralına uy. Adım A1'den başlayalım; önce kurulumlarımı kontrol ettir, kod yazmadan önce mantığı anlat.
