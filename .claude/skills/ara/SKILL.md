---
name: ara
description: Kısa mola / iş değişimi kaydı. Kullanıcı "ara veriyorum", "mola", "birazdan dönerim", "konu değiştiriyoruz" dediğinde ya da /ara yazdığında kullan. Durumu dosyalara yazar ki sohbet /clear ile temizlenebilsin; uygulamaları KAPATMAZ, push ETMEZ.
---

Amaç: sohbet geçmişine bağımlı kalmadan devam edebilmek (uzun sohbet kotayı tüketiyor). Hızlı ol, derleme/test çalıştırma.

1. `memory/project-yukum-next-step.md` dosyasını güncelle (en çok 10 satır değişsin):
   - **Şu an neredeyiz:** hangi adımın hangi alt adımı, kim yazıyor (kullanıcı mı Claude mu), yarım kalan dosya/işlem varsa adı.
   - **Dönünce ilk iş:** tek cümle, uygulanabilir.
   - **Bekleyen kararlar / kullanıcıdan beklenenler.**
   - Bu sohbette verilip dosyada olmayan karar, tercih, bağlantı (URL), kimlik/numara (gizli olmayan) varsa ekle.
2. Bu sohbette bir iş bittiyse `docs/Ilerleme_Gunlugu.md` sonuna tek satır ekle (bitmediyse ekleme).
3. Commit'siz değişiklik varsa: gizli bilgi (parola, anahtar, .p8, secrets) olmadığını kontrol et, `git add -A ios backend docs .claude/scripts .claude/skills` ve yerel commit at (sistemin verdiği Co-Authored-By satırıyla). Derlenmeyen yarım kod varsa commit ATMA, memory'ye "yarım: <dosya>" yaz. Push yok.
4. API ve SQL açık kalsın.
5. Kullanıcıya en çok 3 satır: ne kaydedildi, dönünce ilk iş, ve "Şimdi `/clear` yazabilirsin; dönünce `/baslat`."
