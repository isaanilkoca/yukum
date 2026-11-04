//
//  00_Rehber_Models_Location.swift — Models/Location — telefonun konumu
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// API'ye gitmez; iOS konum servisiyle (CoreLocation) konuşur.
// 
//
//  LocationManager    izin ister, tek seferlik konum alır; sonuçlar iOS'tan 'delegate' fonksiyonlarıyla gelir  ← HomeViewModel'e LocationProviding üzerinden verilir
//  LocationProviding  ViewModel'in gördüğü sözleşme: latitude, longitude, isDenied, errorMessage, request(). CoreLocation'ı ViewModel bilmesin diye
