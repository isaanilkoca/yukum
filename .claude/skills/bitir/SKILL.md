---
name: bitir
description: Gün sonu. Kullanıcı "bitiriyorum", "bugünlük bu kadar", "kapatıyoruz" dediğinde ya da /bitir yazdığında kullan. Günlük + hafıza, derleme, graphify, commit + push, API/SQL kapatma.
---

1. `docs/Ilerleme_Gunlugu.md` sonuna bugünün işini kısa ekle (ne yapıldı, nasıl doğrulandı, kalan/borç). `memory/project-yukum-next-step.md`'yi güncelle: biten, **yarın ilk iş** (tek cümle), bekleyen kararlar, kullanıcıdan beklenenler, çalışma biçimi (kim yazıyor). Yeni oturum YALNIZ bu iki dosyadan devam edecek: sohbette kalıp dosyada olmayan karar/bağlantı/numara bırakma.
2. `bash .claude/scripts/bitir.sh` çalıştır (derleme + graphify + API/SQL kapatma). Derleme hatası varsa kapatma, önce düzelt.
3. Public repo: `git status`'ta gizli bilgi (parola, anahtar, .p8, secrets) olmadığını kontrol et; sonra `git add -A ios backend docs .claude/scripts .claude/skills`, commit (sistemin verdiği Co-Authored-By satırıyla) ve push. Push başarısız olursa nedenini söyle, zorlama (force) yapma.
4. Geçici worktree varsa kaldır (`git worktree list`; scratchpad altındakiler `git worktree remove --force`).
5. Tek satırlık rapor: commit numarası, neyin kapandığı, yarın ilk iş. Sonuna: "Yarın YENİ oturumda `/baslat` yaz (bu sohbeti sürdürme)."
