//
//  CarrierRegisterView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 28.10.2026.
//

import SwiftUI

struct CarrierRegisterView: View {
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var vehicleType = "" // secili arac türü , apiye bu metin gider
    @State private var capacityKg = ""
    @State private var plateNumber = "" // plaka isteğe bağlı
    @State private var kvkkAccepted = false
    @State private var errorMessage : String?
    @State private var isLoading = false
    @State private var isSuccess = false
    
    // Araç türü seçimi için struct'ın içine (body'nin üstüne) bir liste e
    private let vehicleTypes = [
        ("Truck","Tır"),
        ("Lorry","Kamyon"),
        ("Pickup","Kamyonet"),
        ("Refrigerated","Frigorifik"),
        ("Other","Diğer")
    ]
    
    var body: some View {
        GeometryReader { geo in
            ScrollView{
                VStack(spacing: 31){
                    
                    Text("Taşımacı Kaydı").font(.largeTitle).bold()
                    
                    TextField("Ad - Soyad / Firma", text: $fullName).textFieldStyle(.roundedBorder)
                    
                    TextField("E-posta", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder)
                    
                    TextField("Telefon", text: $phone).keyboardType(.phonePad).textFieldStyle(.roundedBorder)
                    
                    SecureField("Şifre",text: $password).textFieldStyle(.roundedBorder)
                    
                    // Picker: açılır seçim listesi; seçilen değer $vehicleType'a yazılır
                    
                    Picker("Araç Türü",selection: $vehicleType){
                        Text("Arac Türünü Seçiniz ").tag("")
                        ForEach(vehicleTypes,id: \.0){ type in  // her tür için bir satır; id: benzersiz anahtar (ilk eleman)
                            Text(type.1).tag(type.0)            // ekranda Türkçe ad, tag = seçilince yazılacak değer
                            
                        }
                    }.pickerStyle(.menu)  // açılır menü görünümü; kapalıyken seçili yazıyı gösterir
                    
                    TextField("Kapasite (kg)",text: $capacityKg).keyboardType(.numberPad).textFieldStyle(.roundedBorder) // sadece rakam klavyesi
                    
                    TextField("Plaka (isteğe bağlı!)",text: $plateNumber).textFieldStyle(.roundedBorder) // sadece rakam klavyesi
                     
                    Toggle("KVKK Metnini onaylıyorum",isOn: $kvkkAccepted)
                    
                    if let errorMessage {Text(errorMessage).foregroundColor(.red)}
                    
                    if isSuccess {Text("Başarıyla kayıt oldunuz. Şimdi giriş yapabilirsiniz.").foregroundColor(.green)}
                    
                    Button("Kayıt Ol"){
                        
                        if fullName.isEmpty || email.isEmpty || password.isEmpty || !kvkkAccepted {
                            errorMessage = "Lütfen zorunlu alanları Doldurun !"
                        }
                        if vehicleType.isEmpty {
                            errorMessage = "Araç türünü seçiniz !"
                        }
                        guard let capacity = Int(capacityKg) else {
                            errorMessage = "Kapasite Sayı Olmalı."
                            return
                        }
                        if !kvkkAccepted {
                            errorMessage = "KVKK metnini onaylamanız gerekir"
                            return
                        }
                        let vehicle = VehicleRequest(
                            type :vehicleType,
                            plateNumber: plateNumber.isEmpty ? nil : plateNumber,
                            capacityKg: capacity
                        )
                        
                        let body = RegisterCarrierRequest(fullName: fullName.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), password: password, phone: phone.trimmingCharacters(in: .whitespaces), homeCityId: 34, vehicles: [vehicle], kvkkAccepted: kvkkAccepted)
                        
                        Task{
                            isLoading = true
                            errorMessage = nil
                            do{
                                _ = try await AuthService().registerCarrier(body)   // _ = cevabı şimdilik kullanmıyoruz
                                isSuccess = true
                            }catch let error as AuthError{
                                errorMessage = error.message
                            }catch{
                                errorMessage = "Sunucuya Ulaşılamadı" // API Kapalı / Baglantı Yok
                            }
                            isLoading = false
                        }
                    }.buttonStyle(.borderedProminent).disabled(isLoading) // istek sürerken basılmaz
                }.padding()
                    .frame(minHeight: geo.size.height)
            }
        }
        
        
    }
}

#Preview {
    CarrierRegisterView()
}
