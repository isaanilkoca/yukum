//
//  APIConfig.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: APIConfig (adres) ───────────────────────────────────────────
// │ NE        : API'nin ana adresi TEK YERDE (http://localhost:5054)
// │ KULLANAN  : Models/Networking/APIClient ve Models/Networking/AuthSession (yenileme/çıkış istekleri) — canlıya çıkarken yalnız burası değişir
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: API'nin ana adresi TEK YERDE. Daha önce her serviste ayrı "baseURL" yazılıydı; canlıya çıkarken hepsini tek tek değiştirmek gerekirdi.
// BAĞLANTI: Models/Networking/APIClient.swift ve Models/Networking/AuthSession.swift buradan okur
// NOT: canlıda https olacak (App Transport Security) ve Debug/Release için ayrı adres tanımlanacak
// ⮕ KULLANIM [APIConfig]: kullanır: APIClient › init(), AuthSession › init()
nonisolated enum APIConfig { // enum [SWIFT]: sabit seçenek listesi
    // ⮕ KULLANIM [baseURL]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    static let baseURL = "http://localhost:5054" // localhost: simülatörde Mac'imiz | 5054: API'nin portu | static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)
}
