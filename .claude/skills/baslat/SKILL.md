---
name: baslat
description: Gün başı — Docker, SQL Server ve API'yi açar, günlükten nerede kaldığımızı özetler. Yüküm oturum başında kullanılır.
disable-model-invocation: true
---

1. `bash .claude/scripts/baslat.sh` çalıştır (tek komut; ayrıca docker/dotnet komutu yazma).
2. Çıktıdaki "Günlüğün son satırları" ve `memory/project-yukum-next-step.md` ile **kısa** özet ver: son yapılan (teknik), bekleyen adım, sıradaki adım.
3. Sıradaki adımı kullanıcı Swift yazacak şekilde, projenin yorum biçimiyle (satır başı `//` yorum, [SWIFT]/[BİZİM], BAĞLANTI:) tarif et. Kullanıcı "geç" demeden sonraki adıma geçme. Sohbette uzun açıklama yok.
