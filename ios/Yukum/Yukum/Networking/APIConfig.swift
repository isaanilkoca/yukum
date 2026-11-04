//
//  APIConfig.swift
//  Yukum
//

import Foundation

// BU DOSYA: API'nin ana adresi TEK YERDE. Daha önce her serviste ayrı "baseURL" yazılıydı; canlıya çıkarken hepsini tek tek değiştirmek gerekirdi.
// BAĞLANTI: Networking/APIClient.swift ve Networking/AuthSession.swift buradan okur
// NOT: canlıda https olacak (App Transport Security) ve Debug/Release için ayrı adres tanımlanacak
nonisolated enum APIConfig {
    static let baseURL = "http://localhost:5054" // localhost: simülatörde Mac'imiz | 5054: API'nin portu
}
