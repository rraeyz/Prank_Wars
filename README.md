# Prank Wars

İki takımın sırayla aynı evi şakalarla tuzakladığı 2–8 kişilik fizik komedisi. Godot 4.4.1 ile yapıldı.

## Oyunu oynamak (Windows, en kolay yol)
1. GitHub'da bu reponun sayfasında sağdaki **Releases** bölümüne gir (ya da `Actions` → en son yeşil çalışma → `PrankWars-Windows`).
2. En yeni `Prank Wars test build N` içindeki **PrankWars-Windows.zip** dosyasını indir.
3. Zip'i bir klasöre **tamamen** çıkar (tüm dosyalar aynı klasörde kalsın) ve `PrankWars.exe`'yi çalıştır.
4. Windows "bilinmeyen yayımcı" uyarısı verirse: **Ek bilgi → Yine de çalıştır**.
5. Kontroller: `HOW_TO_PLAY.txt`.

## Projeyi Godot editöründe açmak
1. https://godotengine.org/download/archive/4.4.1-stable/ adresinden **Godot 4.4.1 (Standard, Windows 64-bit)** indir, zip'ten çıkar, `.exe`'yi aç (kurulum yok).
2. "Import" → bu klasördeki `project.godot` dosyasını seç → "Import & Edit".
3. Sağ üstteki ▶ (F5) ile oyunu başlat.

## Arkadaşla aynı bilgisayarda ağ testi
Editörde: **Debug → Customize Run Instances → Enable Multiple Instances → 2**, sonra F5. Bir pencerede "Oyun Kur", diğerinde "Katıl" (127.0.0.1).

## Otomatik testler (geliştirici)
```
godot --headless --path . --import
tests/run.sh          # birim + entegrasyon testleri (puan, zincir, şakalar, botlu maç)
tests/net_test.sh     # host + istemci, gerçek ağ bağlantısıyla
```
Her push'ta GitHub Actions testleri çalıştırır ve Windows .exe üretir.

## Klasörler
- `scripts/` — tüm oyun kodu (ev, karakter, şakalar, ağ, arayüz, sesler)
- `tests/` — ekransız testler
- `marketing/` — mağaza metinleri, video fikirleri
- `PLAN.md` / `PROGRESS.md` — görev listesi ve çalışma günlüğü
