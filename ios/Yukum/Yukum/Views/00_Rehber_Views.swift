//
//  00_Rehber_Views.swift — VIEWS (GÖRÜNÜM)
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Ekranın SADECE çizimi. Veri, kural ya da API isteği yoktur: her View bir ViewModel'e bağlanır
// (viewModel.x okur, düğmede viewModel.f() çağırır). Sağdaki 'ViewModel' = ViewModels/ klasöründeki karşılığı.
// 
// DOSYA                ViewModel                    NE YAPAR / KİM AÇAR
//
//  LoginView            LoginViewModel            giriş ekranı + açılışta otomatik giriş. ContentView açar; giriş olunca HomeView'ı tam ekran açar
//  RoleSelectionView    (ViewModel yok)             Yük Veren / Taşımacı seçimi. LoginView'dan açılır; RegisterView veya CarrierRegisterView'a götürür
//  RegisterView         RegisterViewModel         Yük Veren kayıt formu. RoleSelectionView açar
//  CarrierRegisterView  CarrierRegisterViewModel  Taşımacı kayıt formu (araç bilgisiyle). RoleSelectionView açar
//  HomeView             HomeViewModel             ana sayfa: Yük Veren kendi ilanlarını, Taşımacı açık ilanları görür (filtre, Yakınımdakiler, rozet, çıkış). Aşağıdaki 5 ekranı açar
//  ListingRow           (ViewModel yok)             listedeki tek ilan satırı; Listing modelini çizer. HomeView listeye dizer
//  ListingDetailView    ListingDetailViewModel    ilan detayı + Teklif Gönder. HomeView'dan (Taşımacı) açılır
//  CreateListingView    CreateListingViewModel    yeni ilan formu. HomeView'dan (Yük Veren) açılır
//  ListingOffersView    ListingOffersViewModel    ilana gelen teklifler: kabul/red, ilanı kaldır, sohbet. HomeView'dan (Yük Veren) açılır
//  MyOffersView         MyOffersViewModel         Taşımacının verdiği teklifler. HomeView'dan açılır; sohbet için ChatView'ı açar
//  OldOffersView        OldOffersViewModel        Yük Verenin karara bağlanmış (geçmiş) teklifleri. HomeView'dan açılır; ChatView'ı açar
//  OpenListingsFilterView (ViewModel yok)    Taşımacı Filtre sayfası (varış, fiyat, araç, tarih, sıralama). HomeView .sheet açar; kopya üzerinde çalışır, Uygula → HomeViewModel.filter
//  FavoritesView        FavoritesViewModel        Taşımacının favori ilanları. HomeView sol üst kalp ikonu açar; satır → ListingDetailView
//  CarrierProfileView   CarrierProfileViewModel   Taşımacı profili: ★ ortalama, tamamlanan iş, yorumlar. ListingOffersView / OldOffersView "Profil" ile açar
//  RatingView           RatingViewModel           Puan ver sayfası (alttan açılır). OldOffersView "Puan ver" ve ChatView (işi bitirince) açar
//  DeleteAccountView    AccountViewModel          Hesabı sil sayfası (şifre onayı). HomeView 'Hesabı Sil' düğmesi .sheet ile açar; başarıda onDeleted → HomeView kapanır → giriş ekranı
//  ChatView             ChatViewModel            teklif sohbeti. MyOffersView / ListingOffersView / OldOffersView açar
//
// API'ye giden kod BURADA YOK. Yolu: View → ViewModels/ → Models/Services/ → Models/Networking/APIClient → sunucu.
