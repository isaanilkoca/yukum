# İl / İlçe Veri Seti — Kaynaklar ve Doğrulama

`il-ilce.json`: **81 il, 973 ilçe** (51'i il merkezi "Merkez" ilçesi). Her il için plaka kodu, il merkezi koordinatı; her ilçe için ad ve ilçe merkezi koordinatı.
Hazırlanma tarihi: 25 Ekim 2026. Bu dosya `Cities` / `Districts` tablolarının tek kaynağıdır (seed).

## Resmî sayılar ve "922 / 973" farkı
- 973 = idari ilçe sayısı. İçişleri Bakanlığı "Mülki İdare Bölümleri Envanteri" sayfasındaki **922**, belediye sayısıdır (519 büyükşehir ilçe belediyesi + 403 ilçe belediyesi) ve 51 il merkezi ilçesini içermez. 922 + 51 = 973.
- Bizde "Merkez" adlı ilçe sayısı tam **51** çıkıyor (verinin kendisinden), yani resmî farkla birebir örtüşüyor.
- Kullanıcı "Aksaray / Merkez" seçebilsin diye il merkezi ilçeleri **dahil** (973).

## Kaynaklar ve rolleri
| Kaynak | Ne için kullanıldı | Lisans | Not |
|---|---|---|---|
| İçişleri Bakanlığı, e-İçişleri Mülki İdare Bölümleri Envanteri | Resmî toplamlar (81 il) | Resmî | İl/ilçe listesi sunmuyor, yalnız sayı |
| Türkçe Vikipedi "Türkiye'nin ilçeleri" tablosu | İlçe adları (3. bağımsız kaynak), ilçe koordinatı (birincil) | CC BY-SA 4.0 | 973 satır; 9 koordinatı hatalı bulundu (aşağıda) |
| Türkçe Vikipedi "Türkiye'nin illeri" tablosu | Plaka kodu doğrulaması | CC BY-SA 4.0 | 81/81 tutarlı |
| GeoNames (`TR.zip`) | Koordinat çapraz kontrolü, 9 düzeltme, il merkezi koordinatı | CC BY 4.0 | ADM2, PPLA, PPLA2 kayıtları |
| Wikidata (SPARQL) | Koordinat çapraz kontrolü | CC0 | **Plaka alanı hatalı** (Konya=53, Uşak=62 yazıyor); isimleri Vikipedi başlığı gibi (ek ifadeli), isim kaynağı olarak kullanılmadı |
| GitHub `nidea1/Turkey-s-Provinces-Districts`, `snrylmz/il-ilce-json` | İsim/plaka çapraz kontrolü | Lisans belirtilmemiş | Yalnız doğrulamada kullanıldı, veri buradan kopyalanmadı. İkisi birbirleriyle 81 ilin tamamında aynı. `nidea1`'in `id` alanı plaka değil **alfabetik sıra** |

Koordinat atıfı: GeoNames (CC BY 4.0), Vikipedi katkıcıları (CC BY-SA 4.0).

## Yöntem
1. İsimler: iki GitHub seti + Vikipedi tablosu üç yönlü karşılaştırıldı → 81 ilin tamamında **sıfır fark**. Yalnız iki açıklanabilir kural: "Merkez" ≡ il adındaki ilçe; yazım işareti (â, î, û) kaldırıldı.
2. Plaka kodları: ikinci GitHub seti ↔ Vikipedi il tablosu 81/81 aynı; Wikidata ile 79/81 (2 Wikidata hatası).
3. İlçe koordinatları: her ilçe için Vikipedi, GeoNames ve Wikidata kıyaslandı. Vikipedi değeri diğerlerinden **en az biriyle 20 km içinde** ise onaylı (955 ilçe). Uyuşmayanlar tek tek incelendi (18 ilçe).
4. İl merkezi koordinatı: GeoNames il merkezi (PPLA). Doğrulama: her ilin merkezi, Vikipedi'deki en yakın ilçe merkezine ortalama 0,8 km (en kötü 8,5 km, Malatya) uzaklıkta.
5. Değişmez kontrolleri: 81 il, plaka 1–81, 973 ilçe, 51 "Merkez", Türkiye sınır kutusu içinde, ilde yinelenen ad yok, aynı koordinatı paylaşan ilçe yok.

## Vikipedi'de bulunan koordinat hataları (düzeltildi)
| İl / İlçe | Sorun | Kullanılan |
|---|---|---|
| Bitlis / Adilcevaz | Bitlis Merkez'in koordinatı kopyalanmış | GeoNames |
| Hakkari / Yüksekova | Şemdinli'nin koordinatı kopyalanmış | GeoNames |
| Mersin / Çamlıyayla | Bozyazı'nın koordinatı kopyalanmış | GeoNames (ilçe merkezi) |
| Bolu / Gerede | Dörtdivan'ın koordinatı kopyalanmış | GeoNames (ilçe merkezi) |
| Denizli / Kale | Pamukkale'nin koordinatı kopyalanmış | GeoNames (ilçe merkezi) |
| Van / Çaldıran | 122 km uzakta | GeoNames (ilçe merkezi) |
| Manisa / Selendi | 113 km uzakta | GeoNames |
| Kocaeli / Kartepe | 35 km uzakta | GeoNames (ilçe merkezi) |
| Hatay / Defne | 28–38 km uzakta | GeoNames |

## Kararlar
- İlçe adı yazımı: Türkçe harfler korunur, circumflex kaldırılır (Kahta, Bala, Kağıthane, Hakkari). Resmî adres kayıtları ve kullanıcının arama alışkanlığı böyle.
- Zonguldak'taki ilçe `Ereğli` (Vikipedi başlığı "Karadeniz Ereğli"); Konya'daki `Ereğli` ile il altında ayrışır.
- Koordinat anlamı: ilçe merkezi (ilçe yerleşiminin konumu), alan ağırlık merkezi değil. Yalnız yaklaşık yakınlık (“bana yakın”) için; hassas rota için kullanılmaz.
- Doğruluk sınırı: "onaylı" 955 ilçede iki bağımsız kaynak 20 km içinde uyuşuyor; ilçe merkezi seçimi küçük farklılıklar (birkaç km) içerebilir.

## Yeniden doğrulama
Kaynaklar ve eşleştirme kuralları yukarıda. İl/ilçe değişikliği (yeni ilçe, ad değişikliği) olursa: `il-ilce.json` güncellenir, yeni migration ile seed değişir (Rapor 21.1: genişlet–doldur–daralt).
