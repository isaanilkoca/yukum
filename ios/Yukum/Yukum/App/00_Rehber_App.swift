//
//  00_Rehber_App.swift — App — uygulamanın girişi
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// MVVM dışı; sadece başlatır.
// 
//
//  YukumApp     uygulama buradan başlar; ilk ekranı açar. Üstünde tüm projenin haritası var
//  ContentView  LoginView'ı taşıyan kap
//  AppDelegate  uygulama olayları (push adresi geldi, bildirime dokunuldu, uygulama açıkken bildirim geldi). Mantık yok: PushManager’a ve anons panosuna (pushTapped, pushReceived) aktarır. YukumApp @UIApplicationDelegateAdaptor ile bağlar
