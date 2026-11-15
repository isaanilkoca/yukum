//
//  00_Rehber_Models_Services.swift — Models/Services/ — API UÇLARI (her fonksiyon = bir uç)
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Sunucudaki her uç için tek fonksiyon. İş mantığı YOK: "şu adrese şu paketle git" der, APIClient gönderir.
//
// YAZIM KURALI: struct XService { init(api: APIClient = .shared) } + extension XService: XServicing {}
//   init(api:) — uygulamada ortak istemci; testte sahte ağlı istemci (YukumTests/Networking/ServiceContractTests her ucu sınar)
//
// SERVİS → FONKSİYON → UÇ   (hepsi /api/v1 altında; (A) = jetonsuz/anonim)
//  AuthService          register (A) POST auth/register/shipper · registerCarrier (A) POST auth/register/carrier · login (A) POST auth/login
//                       sendVerificationCode (A) POST auth/verify-email/send · verifyEmail (A) POST auth/verify-email
//                       forgotPassword (A) POST auth/password/forgot · resetPassword (A) POST auth/password/reset
//  AccountService       profile GET account/me · update PUT account/me · uploadAvatar POST account/avatar (multipart)
//                       deleteAvatar DELETE account/avatar · deleteAccount POST account/delete
//  CityService          cities (A) GET cities · districts (A) GET cities/{id}/districts
//  ListingService       create POST listings · update PUT listings/{id} · cancel POST listings/{id}/cancel
//                       myListings GET listings/mine · allMyListings GET listings/mine?all=true · openListings GET listings?filtre…
//                       setFavorite PUT/DELETE listings/{id}/favorite · favorites GET listings/favorites
//                       recordView POST listings/{id}/view · stats GET listings/{id}/stats · priceReference GET price-reference?…
//  OfferService         create POST listings/{id}/offers · listingOffers GET listings/{id}/offers · decide POST offers/{id}/accept|reject
//                       myOffers GET offers/mine · unseenCount GET offers/mine/unseen-count · markSeen POST offers/mine/seen
//                       hide DELETE offers/{id} · withdraw POST offers/{id}/withdraw · advance POST offers/{id}/advance
//                       shipperHistory GET offers/history · requestCancel POST offers/{id}/cancel-request
//                       approveCancel / rejectCancel POST …/cancel-request/approve|reject · withdrawCancel DELETE offers/{id}/cancel-request
//  ChatService          messages GET offers/{id}/messages · send POST offers/{id}/messages · clear DELETE offers/{id}/messages
//                       complete POST offers/{id}/complete (işi bitir)
//  ReviewService        create POST offers/{id}/review · carrierProfile GET carriers/{id} · shipperProfile GET shippers/{id}
//  NotificationService  list GET notifications?page · unreadCount GET notifications/unread-count · markRead POST notifications/{id}/read
//                       markAllRead POST notifications/read-all · delete DELETE notifications/{id}
//                       registerDevice PUT notifications/device-token · removeDevice DELETE notifications/device-token?deviceId=
//  VehicleService       mine GET vehicles · add POST vehicles · update PUT vehicles/{id} · delete DELETE vehicles/{id}
//  SafetyService        block PUT users/{id}/block · unblock DELETE users/{id}/block · blocked GET account/blocks · report POST users/{id}/report
//
// ALT KLASÖR: Protocols/ — her servisin sözleşmesi (…Servicing)
// KULLANAN: ViewModels/* (servisi doğrudan değil, protokolü üzerinden)
