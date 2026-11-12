//
//  APIConfig.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: APIConfig (adres) ───────────────────────────────────────────
// │ NE        : API'nin ana adresi TEK YERDE (simülatör: http://localhost:5054 | gerçek cihaz: http://<Mac'in yerel IP'si>:5054)
// │ KULLANAN  : Models/Networking/APIClient ve Models/Networking/AuthSession (yenileme/çıkış istekleri) — canlıya çıkarken yalnız burası değişir
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: API'nin ana adresi TEK YERDE. Daha önce her serviste ayrı "baseURL" yazılıydı; canlıya çıkarken hepsini tek tek değiştirmek gerekirdi.
// BAĞLANTI: Models/Networking/APIClient.swift ve Models/Networking/AuthSession.swift buradan okur
// NOT: canlıda https olacak (App Transport Security) ve Debug/Release için ayrı adres tanımlanacak
// ⮕ KULLANIM [APIConfig]: kullanır: APIClient › init(), AuthSession › init()
nonisolated enum APIConfig { // enum [SWIFT]: sabit seçenek listesi
    // ⮕ KULLANIM [baseURL]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    // NEDEN İKİ ADRES: "localhost" = uygulamanın çalıştığı cihazın KENDİSİ. Simülatör Mac'in içinde çalışır → localhost Mac'tir (API orada).
    // Gerçek iPhone'da localhost telefonun kendisidir, orada API yok → Mac'e yerel ağdaki IP'siyle gidilir (telefon ve Mac AYNI Wi-Fi'de olmalı).
    // #if targetEnvironment(simulator) [SWIFT]: derleme anında seçilir; simülatör derlemesine yalnız ilk dal, telefon derlemesine yalnız ikinci dal girer
    // http serbest: Info.plist › NSAllowsLocalNetworking (yalnız yerel ağ adresleri) | API telefondan erişilsin diye 0.0.0.0'da dinlemeli (--urls http://0.0.0.0:5054)
    #if targetEnvironment(simulator)
    static let baseURL = "http://localhost:5054" // 5054: API'nin portu | static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)
    #else
    static let baseURL = "http://\(devMachineHost):5054" // gerçek cihaz → Mac
    #endif

    // devMachineHost: Mac'in yerel ağ IP'si | Wi-Fi değişince değişir → Terminal: ipconfig getifaddr en0 | canlıda burası https alan adı olacak
    static let devMachineHost = "192.168.1.46"
}
