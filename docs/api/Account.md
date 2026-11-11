# Sözleşme kartı: Hesap silme

`POST /api/v1/account/delete` (giriş yapmış her rol) — gövde: `{ "password": "..." }`

- **204** başarılı: hesap anonimleştirildi, tüm oturumlar kapandı. iOS bu cevaptan sonra yerel oturumu (Keychain) temizleyip giriş ekranına döner.
- **400** `Şifre hatalı.` ya da `Hesabı silmek için şifreni gir.` — **401 değildir**: iOS 401'i "oturum bitti" sayıp çıkış yaptırır, yanlış şifre oturumu bitirmemeli.
- **409** `Devam eden bir işin var...` — kabul edilmiş ama tamamlanmamış işi olan (Yük Veren ya da Taşımacı) silemez; önce işi tamamlar ya da ilanı iptal eder.
- **401** jeton yok. **429** çok fazla deneme (giriş ucuyla aynı hız sınırı).

**Silince ne olur:** Açık ilanlar kaldırılır ve üzerindeki bekleyen teklifler iptal olur; Taşımacı'nın bekleyen teklifleri geri çekilir. Favori ve görüntülenme kayıtları silinir. Ad, e-posta, telefon, şifre, firma/vergi bilgisi ve araç plakaları temizlenir; hesap "Silinmiş Kullanıcı" olarak kalır. Aynı e-posta ve telefon yeniden kayıt olabilir.
