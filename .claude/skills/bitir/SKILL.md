---
name: bitir
description: Gün sonu — derleme, graphify, günlük, commit+push ve uygulamaları kapatma. Yüküm oturum sonunda kullanılır.
disable-model-invocation: true
---

1. `docs/Ilerleme_Gunlugu.md` sonuna bugünün işini (ne yapıldı, doğrulama, kalan/borç) kısa ekle; `memory/project-yukum-next-step.md`'yi "yarın ilk iş" ile güncelle.
2. `bash .claude/scripts/bitir.sh` çalıştır (derleme + graphify + API/SQL kapatma). Derleme hatası varsa kapatma, önce düzelt.
3. Public repo: `git status`'ta gizli bilgi (parola, anahtar, .p8, secrets) olmadığını kontrol et; sonra `git add -A ios backend docs .claude/scripts .claude/skills` ve commit (sonuna `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`) + push.
4. Tek satırlık rapor: commit numarası, neyin kapandığı, yarın ilk iş.
