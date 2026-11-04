//
//  00_Rehber_Models_Services.swift — Models/Services — API'ye konuşan yer
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Her fonksiyon BİR API ucudur: 'hangi adres, hangi paket, ne döner'. İsteği APIClient (Networking/) gönderir.
// Çağıran: ViewModels/. Servis ViewModel'e Protocols/ içindeki sözleşme üzerinden görünür.
// 
//
//  AuthService     POST /auth/login · /auth/register/shipper · /auth/register/carrier  ← LoginViewModel, RegisterViewModel, CarrierRegisterViewModel
//  ListingService  GET /listings (il/ilçe/konum) · GET /listings/mine · POST /listings · POST /listings/{id}/cancel  ← HomeViewModel, CreateListingViewModel, ListingOffersViewModel
//  OfferService    POST+GET /listings/{id}/offers · GET /offers/mine · /offers/history · /offers/mine/unseen-count · POST /offers/mine/seen · /offers/{id}/accept|reject|complete · DELETE /offers/{id}  ← 6 ViewModel
//  ChatService     GET · POST · DELETE /offers/{id}/messages  ← ChatViewModel
//  CityService     GET /cities · GET /cities/{id}/districts  ← HomeViewModel, CreateListingViewModel
//  Protocols/      her servisin sözleşmesi (…Servicing) — test için sahtesi takılabilsin diye
