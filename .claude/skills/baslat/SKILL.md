---
name: baslat
description: Oturum başı. Kullanıcı /baslat yazdığında ya da "başlayalım", "devam edelim, nerede kalmıştık" dediğinde kullan. Docker, SQL Server ve API'yi açar; nerede kaldığımızı DOSYALARDAN özetler.
---

1. `bash .claude/scripts/baslat.sh` çalıştır (tek komut; ayrıca docker/dotnet komutu yazma).
2. Durumu yalnız şuralardan oku: script çıktısındaki "Günlüğün son satırları" ve `memory/project-yukum-next-step.md`. Eski sohbet dökümünü (.jsonl) OKUMA; gerekirse yalnız ilgili kod dosyasına bak. `git status --short` ile commit'siz/yarım iş var mı kontrol et.
3. En çok 6 satır özet: son yapılan (teknik), yarım kalan, kullanıcıdan beklenen, sıradaki adım.
4. Sıradaki adıma memory'deki **çalışma biçimine** göre başla:
   - Kullanıcı yazacaksa: doğrulanmış kodu projenin yorum biçimiyle (satır başı `//`, [SWIFT]/[BİZİM], BAĞLANTI HARİTASI, ZİNCİR, NEDEN) ver, "bul → altına ekle" tarifleriyle; kullanıcı "tamam" deyince kontrol et.
   - Claude yazacaksa: yaz, test et, teknik anlatımı SOHBETE DEĞİL kod yorumlarına koy.
5. Kullanıcı "geç" ya da "tamam" demeden sonraki adıma geçme. Sohbet kısa kalsın.
