# Prank Wars — PROGRESS

Her oturumun sonunda buraya kısa bir kayıt eklenir (en yeni en üstte).
Sonraki oturum: önce `PLAN.md`, sonra bu dosyanın en üstündeki kaydı oku.

## Ortam notları (bulut oturumu için)
- Godot 4.4.1 Linux: `/opt/godot/Godot_v4.4.1-stable_linux.x86_64` (`godot` olarak link). Container silinirse yeniden kur:
  `curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip`
- Export şablonları: `~/.local/share/godot/export_templates/4.4.1.stable/` (aynı release sayfasından `..._export_templates.tpz`).
- Testler: `tests/run.sh` (birim+entegrasyon) ve `tests/net_test.sh` (ağ)
- Ekran görüntüsü için: `xvfb-run -a godot --path . --rendering-driver opengl3 ...`
- kenney.nl ve api.github.com bu ortamdan 403 veriyor; github.com release indirmeleri çalışıyor.

---

## Oturum 2 — 2026-11-01 (kullanıcı isteği)
- İstek: raunt daha uzun, varsayılan maç 8–10 dk, özel ayar; bekleyen takım izlesin ve müdahale etsin; açık/bug kapat.
- Yapılan: hazırlık 90 sn + görev 150 sn, 2 raunt ≈ 9 dk (lobide değiştirilebilir). Görev uzayınca 4 görev seçiliyor.
- Hayalet modu: görevde izleyen kuran takımı 20 sn sonra G / sağ tık / E ile yakındaki eşyayı koşucuya fırlatıyor (12 sn bekleme).
  Hazırlıkta koşucuların içeriyi izlemesine izin verilmedi (tuzakların yeri belli olur, sürpriz biter).
- Güvenlik/bug: host yerleştirmeyi kendi verisinden yeniden kuruyor; NaN/yanlış yuva/tip uyuşmazlığı reddediliyor; bozuk istemci eylemleri yok sayılıyor;
  maçta takım değiştirme, çift kayıt engellendi; isimlerden satır sonu temizleniyor; lobi ayarları istemcilere senkron.
- Testler: 116 kontrol + ağ testi geçiyor.
- Sıradaki: kullanıcı testi (hayalet eğlenceli mi, 9 dk uygun mu).

## Oturum 1 — 2026-11-01
**Yapılanlar**
- Repo boştu → PLAN/PROGRESS, Godot 4.4.1 ekransız kurulum, saatlik devam tetikleyicisi (trig_01D7JsQ4ygenfeoS1eemUZF7, her saat :30).
- Tüm oyun koddan yazıldı (`scripts/`): tek katlı ev (5 oda + bahçe), fasulye karakter (devrilme/kalkma, kollar, oynak gözler),
  14 şaka, 8 görev, puan + zincir, raunt akışı (intro → hazırlık 60 sn → görev 100 sn → tekrar → skor), HUD, menü, lobi, ayarlar,
  TR/EN, gamepad, botlar (kuran + koşucu), antrenman modu, sentez ses + müzik, ağır çekim tekrar + filigran.
- Ağ: host yetkili ENet (20 Hz durum paketi + yumuşatma), oyuncu ayrılırsa yerine bot geçer. Steam katmanı (`steam_net.gd`) yazıldı.
- Testler: `tests/run.sh` (78 kontrol: puan, zincir, muz, kova, boya, yay, kombo, çarpışma zinciri, görev akışı, etkisiz bırakma, yerleştirme, tam botlu maç) ve `tests/net_test.sh` (iki süreçli gerçek ağ) — hepsi geçiyor.
- GitHub Actions: her push'ta test + ağ testi + Windows .exe; Releases'e "Prank Wars test build N" olarak zip yüklüyor.

**Çalışanlar:** botlu antrenman maçı baştan sona; ağ testi (localhost); Windows/Linux dışa aktarma.
**Bilinmeyen / test edilmedi:** Steam lobisi (bu ortamda Steam yok ve indirilen eklentiyi çalıştırma izni yok — kod GodotSteam 4.23.2 API'sine göre yazıldı, ilk gerçek testte hata çıkabilir). Gerçek GPU'da performans. Oyun hissi (komik mi?).
**Not:** kenney.nl bu ortamdan 403 → modeller koddan üretiliyor.

**KULLANICI BEKLENİYOR — Kullanıcı testi 1 (prototip, ~20 dk)**
1. GitHub → repo → sağda *Releases* → en yeni "Prank Wars test build" → `PrankWars-Windows.zip` indir, bir klasöre çıkar, `PrankWars.exe` çalıştır (uyarıda "Ek bilgi → Yine de çalıştır").
2. *Antrenman (botlarla)* → *Başlat*. Bir maç oyna (sen kurarken ve koşarken).
3. Sonra aynı bilgisayarda iki kez aç: birinde *Oyun Kur*, diğerinde *Katıl* (127.0.0.1) → ağın çalıştığını gör.
4. Bir arkadaşla dene (aynı Wi-Fi'da kurucunun ekranında yazan IP ile; internetten ise Radmin VPN/ZeroTier gibi ücretsiz sanal LAN).
5. Bana yaz: güldünüz mü? En komik an neydi? Ne sıkıcıydı? Kontroller rahat mı? FPS düşük mü? Hata/çökme oldu mu?

**Oturum 1 devamı (aynı gün)**
- Kum havuzu modu (sınırsız tuzak, kendini şakala, Backspace yenile, Delete sil, T uzaktan hepsini patlat).
- Fareyle gösterilen yere şaka koyma; uzaktan şakalarda [1]-[9] etiketleri, tıklayarak patlatma.
- İpuçları, "Nasıl Oynanır" ekranı, raunt giriş kartı, krediler, F9 ekran görüntüsü, sersemleme yıldızları, kontur çizgileri, bahçe süsleri.
- Demo dışa aktarma (5 şaka) — CI `PrankWarsDemo-Windows.zip` de üretiyor.
- Ağ: 30 Hz, kendi karakterin daha taze; maç sürerken katılma reddi.
- Pazarlama: `marketing/` (mağaza metni, basın kiti, yayıncı mesajı, video fikirleri), `tools/keyart.gd` tanıtım görseli aracı.
- Testler: 86 kontrol + ağ testi geçiyor; CI yeşil.

**Oturum 1 son eklemeler:** 7 dil (TR/EN/ES/PT/DE/FR/RU), tuş atama ekranı, gamepad ile menü, botlar bazı tuzaklardan kaçıyor, hazırlıkta kapıdan içeri bakma açığı kapatıldı. 101 test + ağ testi geçiyor.
**Durum:** PLAN.md'de yapılabilecek tüm [ ] görevler bitti; kalanlar kullanıcı testine bağlı ([K]/[~]). Saatlik tetikleyici bu yüzden kapatıldı — kullanıcı geri bildirim verince yeniden açılabilir.

**Sıradaki:** Kullanıcı testi 1 sonuçlarına göre mekanik/denge değişiklikleri. Steam lobisinin ilk gerçek testi (Kullanıcı testi 2).
