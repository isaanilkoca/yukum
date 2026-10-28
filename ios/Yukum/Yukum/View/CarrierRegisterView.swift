//
//  CarrierRegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI

// BU EKRAN: Taşımacı kayıt formu. Akış: alanları doldur → kontrol et → pakete koy → AuthService ile API'ye gönder → sonucu göster
// [BİZİM] = adı biz koyduk | [SWIFT] = Swift/SwiftUI'nin hazır kodu

struct CarrierRegisterView: View {

    // @State [SWIFT]: ekranın hafızası; değer değişince ekran kendini yeniler
    @State private var fullName = "" // ad soyad / firma
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var vehicleType = "" // seçili araç türü; API'ye bu metin gider | "" = henüz seçilmedi
    @State private var capacityKg = "" // TextField yazı tuttuğu için String; göndermeden önce sayıya çevireceğiz
    @State private var plateNumber = "" // plaka, isteğe bağlı
    @State private var kvkkAccepted = false // Toggle açık/kapalı → true/false
    @State private var errorMessage : String? // ? = boş olabilir | nil: hata yok, dolu: ekranda kırmızı yazılır
    @State private var isLoading = false // istek sürerken true → düğme kilitlenir
    @State private var isSuccess = false // kayıt olunca true → yeşil mesaj çıkar

    // (API'ye giden değer, ekranda görünen ad) çiftleri | API'nin tanıdığı yazım: Truck, Lorry, Pickup, Refrigerated, Other
    private let vehicleTypes = [
        ("Truck","Tır"),
        ("Lorry","Kamyon"),
        ("Pickup","Kamyonet"),
        ("Refrigerated","Frigorifik"),
        ("Other","Diğer")
    ]

    var body: some View {
        GeometryReader { geo in // geo: ekranın ölçüsü | ScrollView içeriğini ortalamak için kullanıyoruz
            ScrollView{ // klavye açılınca/uzun formda kaydırma
                VStack(spacing: 31){ // elemanları alt alta dizer

                    Text("Taşımacı Kaydı").font(.largeTitle).bold()

                    // TextField(ipucu, text: $değişken) | $: iki yönlü bağ, yazılan yazı doğrudan değişkene gider
                    TextField("Ad - Soyad / Firma", text: $fullName).textFieldStyle(.roundedBorder)

                    TextField("E-posta", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder) // .never: baş harf büyümesin | .emailAddress: @ kolay çıkan klavye

                    TextField("Telefon", text: $phone).keyboardType(.phonePad).textFieldStyle(.roundedBorder) // .phonePad: telefon klavyesi

                    SecureField("Şifre",text: $password).textFieldStyle(.roundedBorder) // yazılan nokta nokta görünür

                    // Picker: açılır liste | selection: $vehicleType → seçilen değer bu değişkene yazılır
                    Picker("Araç Türü",selection: $vehicleType){
                        Text("Araç Türünü Seçiniz").tag("") // tag(""): boş değerle eşleşir → hiçbir şey seçilmemişken bu yazı görünür
                        ForEach(vehicleTypes,id: \.0){ type in // her tür için bir satır | id: \.0 = benzersiz anahtar olarak çiftin 1. elemanı (Truck, Lorry...)
                            Text(type.1).tag(type.0) // type.1: ekranda görünen Türkçe ad | type.0 = tag: seçilince değişkene yazılacak API değeri
                        }
                    }.pickerStyle(.menu) // açılır menü görünümü

                    TextField("Kapasite (kg)",text: $capacityKg).keyboardType(.numberPad).textFieldStyle(.roundedBorder) // .numberPad: sadece rakam klavyesi

                    TextField("Plaka (isteğe bağlı)",text: $plateNumber).textFieldStyle(.roundedBorder)

                    Toggle("KVKK Metnini onaylıyorum",isOn: $kvkkAccepted) // aç/kapa anahtarı; $ ile true/false değişkene yazılır

                    // if let errorMessage: doluysa içini çıkarıp göster, nil ise bu satır hiç çizilmez
                    if let errorMessage {Text(errorMessage).foregroundColor(.red)}

                    // isSuccess true olunca yeşil başarı yazısı çıkar
                    if isSuccess {Text("Başarıyla kayıt oldunuz. Şimdi giriş yapabilirsiniz.").foregroundColor(.green)}

                    Button("Kayıt Ol"){

                        // ---- 1) KONTROLLER: API'ye gitmeden ekranda yakalıyoruz ----
                        // isEmpty: yazı boş mu | ||: veya | return: burada dur, API'ye gitme (return yazmazsak kod devam eder!)
                        if fullName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty {
                            errorMessage = "Lütfen zorunlu alanları doldurun !"
                            return
                        }
                        if vehicleType.isEmpty { // Picker'da hâlâ "Araç Türünü Seçiniz" duruyor
                            errorMessage = "Araç türünü seçiniz !"
                            return
                        }
                        // Int(capacityKg): yazıyı sayıya çevirir | Int("24000") → 24000, Int("abc") → nil
                        // guard let: nil değilse sonucu capacity'ye koy ve devam et, nil ise else içine gir ve dur
                        guard let capacity = Int(capacityKg) else {
                            errorMessage = "Kapasite sayı olmalı."
                            return
                        }
                        if !kvkkAccepted { // !: değil → onay verilmemişse
                            errorMessage = "KVKK metnini onaylamanız gerekir."
                            return
                        }

                        // ---- 2) PAKETİ HAZIRLA ----
                        // Fikir: API'ye "ekranı" göndermeyiz, sadece bilgileri göndeririz. Bilgiler API'nin istediği FORM KAĞIDINA yazılır.
                        // Form kağıtlarının kalıbı Network/RegisterRequest.swift'te: VehicleRequest (araç) ve RegisterCarrierRequest (tüm kayıt).
                        // Örnek: kullanıcı "Truck", "24000", "34 ABC 123" girdi →
                        //   vehicle = VehicleRequest(type: "Truck", plateNumber: "34 ABC 123", capacityKg: 24000)
                        //   body    = RegisterCarrierRequest(fullName: "Ali", ..., vehicles: [vehicle], ...)
                        // body artık "gönderilecek dolu form kağıdı"; henüz internete çıkmadı, sadece hazır.
                        let vehicle = VehicleRequest( // tek araç paketi
                            type: vehicleType,
                            plateNumber: plateNumber.isEmpty ? nil : plateNumber, // boşsa nil: JSON'a hiç yazılmaz (a ? b : c = a doğruysa b, değilse c)
                            capacityKg: capacity // sayıya çevrilmiş hali
                        )

                        // .trimmingCharacters(in: .whitespaces) [SWIFT]: baş ve sondaki boşlukları siler (yanlışlıkla boşluk bırakılırsa API reddetmesin)
                        // homeCityId: 34 → şimdilik sabit İstanbul | vehicles: [vehicle] → tek elemanlı liste
                        // DİKKAT: parametre sırası RegisterCarrierRequest'teki alan sırasıyla aynı olmalı
                        let body = RegisterCarrierRequest(fullName: fullName.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), password: password, phone: phone.trimmingCharacters(in: .whitespaces), homeCityId: 34, vehicles: [vehicle], kvkkAccepted: kvkkAccepted)

                        // ---- 3) API'YE GÖNDER ----
                        // Ekran sadece "AuthService, bunu yolla" der; internet işini AuthService yapar (Network/AuthService.swift):
                        //   registerCarrier(body) → post("/api/v1/auth/register/carrier", body) →
                        //   body JSON'a çevrilir → URLSession ile http://localhost:5054/api/v1/auth/register/carrier adresine POST edilir →
                        //   API cevap verir (201 oldu / 400 hatalı / 409 zaten kayıtlı) → AuthService cevabı döndürür ya da hata fırlatır.
                        // Bekleme süresince ekran donmasın diye Task + await kullanıyoruz.
                        // Sonuç:  başarılı → isSuccess = true (yeşil yazı) | AuthError → errorMessage (API'nin Türkçe mesajı) | diğer → "Sunucuya ulaşılamadı"
                        Task{ // Task [SWIFT]: düğme içinde await (bekleme) kullanabilmemizi sağlar
                            isLoading = true // düğme kilitlenir
                            errorMessage = nil // eski hatayı temizle
                            do{ // do: dene | hata çıkarsa aşağıdaki catch'lerden biri çalışır
                                // AuthService().registerCarrier(body): API ile bağlantıyı kuran kod (Network/AuthService.swift)
                                // try await: hata çıkabilir + cevabı bekle | _ =: dönen cevabı şimdilik kullanmıyoruz
                                _ = try await AuthService().registerCarrier(body)
                                isSuccess = true // başarılı → yeşil mesaj çıkar
                            }catch let error as AuthError{ // API "hayır" dedi (400, 409...)
                                errorMessage = error.message // API'nin Türkçe mesajı kırmızı yazılır
                            }catch{ // başka her hata: API kapalı, internet yok
                                errorMessage = "Sunucuya ulaşılamadı."
                            }
                            isLoading = false // düğme tekrar açılır
                        }
                    }.buttonStyle(.borderedProminent).disabled(isLoading) // .disabled: isLoading true iken basılamaz (çift tıklama olmasın)
                }.padding()
                    .frame(minHeight: geo.size.height) // en az ekran boyu: içerik ortada durur, uzunsa kaydırılır
            }
        }
    }
}

#Preview {
    CarrierRegisterView()
}
