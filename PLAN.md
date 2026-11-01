# Prank Wars — PLAN

Bu dosya projenin görev listesidir. Her oturum bu dosyayı ve `PROGRESS.md`'yi okuyup ilk `[ ]` görevden devam eder.
İşaretler: `[x]` bitti · `[ ]` yapılacak · `[~]` kısmen / kullanıcı testi bekliyor · `[K]` sadece kullanıcı yapabilir · `[-]` bilerek ertelendi.

## Rapordan yapılan büyük değişiklikler (neden)

1. **Kamera: omuz üstü yerine yukarıdan açılı takip kamerası, kameraya bakan duvarlar şeffaflaşır.**
   Klipte tuzak ile düşen karakter aynı karede görünür; kamera duvara girmez; 5 saniyede anlaşılır. Bu yüzden ev **tek katlı** (iki kat yukarıdan okunaksız olur).
2. **Raunt kısaldı: hazırlık 60 sn, görev 100 sn (raunt ~3 dk, maç ~13 dk).**
   Yayında ölü zaman satış öldürür. Süreler `game_config.gd` içinde tek yerden değişir.
3. **Bekleyen takım boş durmaz:** hazırlıkta koşucular bahçede birbirini itip, kendini yere atıp (dalış), eşya fırlatabilir; evin içini görmezler ama sesleri duyarlar.
4. **Botlar en baştan var** (raporda "çıkıştan sonra"). Tek başına test, antrenman modu, otomatik testler ve video çekimi için gerekli.
5. **Ağ: önce Godot'un yerleşik ENet bağlantısı (IP ile / aynı PC'de iki pencere), Steam lobisi sonra üstüne eklenir.**
   ENet ekransız testlerde çalıştırılabiliyor; Steam ancak gerçek Steam istemcisiyle test edilir.
6. **Karakter: tam iskelet ragdoll yerine "devrilen fasulye" gövde + sallanan kollar.**
   Tek fizik gövdesi olduğu için ağda senkronize etmek kolay ve düşüşler daha komik.
7. **Görsel ve ses önce koddan üretilir** (basit şekiller, sentezlenmiş sesler): lisans riski sıfır. CC0 paketler sonra eklenir.
8. **Şakalar yaklaşınca görünür:** koşucu yerdeki tuzağı sadece ~2,5 m yakınındayken görür ("eyvah!" anı), kuran takım hepsini görür.
9. **Klip kaydı:** oyun içinde ağır çekim tekrar + köşede oyun adı filigranı. Video dosyası için Steam'in kendi "Oyun Kaydı" (Game Recording) / Windows Game Bar kullanılır; ayrı GIF kaydedici en sona bırakıldı.

## Faz 0 — Altyapı
- [x] Repo, PLAN.md, PROGRESS.md
- [x] Godot 4.4.1 ekransız kurulum (bulut ortamı) ve export şablonları
- [x] Saatlik devam tetikleyicisi
- [x] Proje iskeleti (project.godot, autoload'lar, giriş tuşları)
- [x] Ekransız test çalıştırıcı (`tests/run_tests.gd`)
- [x] GitHub Actions: testler + Windows .exe derlemesi (artifact)

## Faz 1 — Oynanabilir prototip
- [x] Ev haritası koddan (5 oda + bahçe, kapılar, mobilya, dolaplar)
- [x] Karakter: hareket, zıplama, dalış, devrilme/kalkma, sallanan kollar, gözler
- [x] Kamera: açılı takip + duvar şeffaflaşması; izleyici (kuran takım) kamerası
- [x] Şakalar: muz kabuğu, kapı üstü kova, boya bombası
- [x] Hazırlık modu: şaka seçme, hayalet önizleme, bütçe, yerleştirme kuralları
- [x] Görevler: etkileşim (E basılı tut), taşıma görevleri
- [x] Puanlama + zincir mantığı (saf sınıf, testli)
- [x] Raunt / maç akışı (hazırlık → görev → tekrar → skor, roller değişir)
- [x] HUD (süre, skor, görevler, bütçe, olay akışı, zincir yazısı)
- [x] Botlar (koşucu + kurucu)
- [x] Antrenman modu (sen + botlar)
- [x] Ana menü + lobi
- [x] Testler: puanlama, zincir, şaka tetikleme, botlu tam raunt
- [x] İlk Windows .exe
- [K] **Kullanıcı testi 1:** oyna, arkadaşla oyna, güldünüz mü? (bkz. PROGRESS.md)

## Faz 2 — Çok oyunculu sağlamlık
- [x] Ev sahibi yetkili model: istemci girdileri → host fizik → durum paketleri (20 Hz) + yumuşatma
- [x] Lobi: isim, takım, renk, bot ekle/çıkar, başlat
- [x] Bağlantı kopması / oyuncu ayrılması
- [x] Ekransız iki süreçli ağ testi (host + istemci aynı makinede)
- [~] GodotSteam: Steam lobisi + arkadaş daveti + Steam P2P (kod yazıldı, CI .exe'ye ekliyor; Steam istemcisiyle test edilmedi → Kullanıcı testi 2)
- [K] **Kullanıcı testi 2:** iki bilgisayarla online test

## Faz 3 — İçerik
- [x] 14 şakanın tamamı (yağlı zemin, un torbası, osuruk minderi, boks eldiveni, bant, yay, bilyeler, konfeti, alarm, sahte kumanda, robot süpürge)
- [x] 8 görev
- [x] Tekrar kamerası (en iyi zincir, ağır çekim, filigran)
- [x] Ses efektleri (sentez) + müzik
- [x] Boya / un / su efektleri ve kalıcı lekeler

## Faz 4 — Cila
- [x] Türkçe + İngilizce arayüz
- [x] Ayarlar (ses, dil, tam ekran)
- [x] Gamepad desteği
- [~] CC0 mobilya modelleri (Kenney Furniture Kit) — bu ortamdan kenney.nl'ye erişim yok (403); şimdilik koddan modeller. Kullanıcı isterse zip'i repoya koyabilir
- [x] Performans ve hata düzeltme turu (282 mesh, 73 fizik gövdesi; NaN göz hatası düzeltildi)
- [K] Arkadaş gruplarıyla 4–8 kişilik test

## Faz 5 — Steam'e hazırlık
- [~] Steam sürümü (GodotSteam ile; appID `steam_appid.txt`'den okunuyor, şimdilik 480) — gerçek appID için Steamworks hesabı gerekli
- [x] Mağaza metinleri ve tanıtım klasörü (`marketing/`)
- [K] Steamworks hesabı + $100 ödeme
- [K] Mağaza görselleri / fragman çekimi
- [x] Demo yapılandırması (5 şaka; CI ayrıca PrankWarsDemo-Windows.zip üretiyor)

## Faz 6 — Eğlence ve klip cilası (prototip testinden bağımsız yapılabilenler)
- [x] Kum havuzu / Antrenman evi: sınırsız şaka kur, kendin dene, botlar dolaşsın (içerik üreticileri için)
- [x] Oyun içi ipuçları (ilk raunt için kısa rehber yazıları)
- [x] F9 ile ekran görüntüsü kaydetme (her an)
- [x] Oyun içi krediler / lisans ekranı
- [x] Görsel cila: konturlar, gölgeler, oda süsleri, düşüşte toz/yıldız efekti
- [~] Denge: puanlar, şaka maliyetleri, süreler (botlu maçlarda iki taraf yakın puan alıyor; gerçek oyuncu testine göre ayarlanacak)

## Faz 7 — Kullanıcı testini beklerken
- [x] Maç sürerken katılmaya çalışana "maç devam ediyor" mesajı
- [x] Mağaza görselleri için sahne çekim modu (`tools/keyart.gd`, `-- --keyart=KLASÖR`), 1920x1080
- [x] Basın kiti + yayıncı mesajları (`marketing/`)
- [x] Online his: kendi karakterin ~100 ms daha taze gösteriliyor, durum paketi 30 Hz (tam istemci tahmini değil; online testte hâlâ gecikmeli hissedilirse tam tahmin eklenecek)

## Faz 8 — Dünya pazarı ve erişilebilirlik (saatlik tetikleyici için)
- [x] Gamepad ile menüde gezinme (Steam Deck)
- [x] Yeni diller: İspanyolca, Portekizce (BR), Almanca, Fransızca, Rusça (arayüz metinleri; ipuçları İngilizce kalıyor)
- [x] Tuş atama ekranı (klavye)
- [x] Botlar bazen görünen tuzaktan kaçsın (daha inandırıcı antrenman)
- [-] İkinci harita (ofis) — ertelendi: rapora göre çıkıştan sonra, önce ilk evin test sonucu

## Faz 9 — Kullanıcı isteği (oturum 2)
- [x] Daha uzun raunt: hazırlık 90 sn, görev 150 sn; varsayılan maç 2 raunt ≈ 9 dk
- [x] Lobide özel ayar: raunt sayısı (2/4/6), hazırlık (60/90/120), görev (100/150/200), tahmini süre; istemcilere de gösteriliyor
- [x] Görev sırasında izleyen kuranlar HAYALET: 20 sn sonra eşya fırlatır (12 sn bekleme), koşucu yakındaysa ve eşya yoksa korkutur; puan + zincir sayılır, botlar da kullanır
- [x] Güvenlik: yerleştirme host'ta yeniden hesaplanıyor (NaN, yanlış yuva, yuva/tip uyuşmazlığı), istemci eylemlerinde tip kontrolü, maç sırasında takım değiştirme ve çift kayıt engeli, isim temizleme
- [x] Testler: hayalet + güvenlik testleri (116 kontrol)

## Faz 10 — Çeşitlilik ve sürekli eğlence (oturum 3)
- [x] Ev Kuralları: her raunt rastgele kural (Ay Çekimi, Buz Pisti, Koca Kafalar, Elektrik Kesik, Turbo, Deprem, Çifte Puan); lobide rastgele/kapalı/sabit seçim
- [x] "Annem geliyor!": görevin son 30 sn'si çifte puan, koşucular biraz hızlanır
- [x] Koşucu yeteneği "Kokla" (C / LB): 6 m içindeki gizli tuzakları 3,5 sn gösterir, 25 sn bekleme
- [x] Dans / nanik (V / d-pad aşağı)
- [x] Maç sonu ödülleri: Muz Kurbanı, En Pis, Tuzak Ustası, Ev Hayaleti, Ev Kuşu, Bomba İmhacı
- [x] Rastgele raunt olayları: kedi kaçtı (koşar, tuzak tetikler, yakalayana +10), pizza geldi (bonus görev)
- [x] Yeni şakalar: trambolin (ileri fırlatır, 3 kullanım), tuzaklı pasta (yem: yiyen +5 alır ama suratına krema)
- [x] KAOS modu: sıra yok; iki takım aynı anda kurar ve koşar, bütçe 5 sn'de +1 dolar, kendi tuzağın sana zarar vermez, olaylar + annem geliyor dahil (lobide Mod seçimi)
- [x] Kozmetik: 7 şapka (parti, taç, kep, aşçı, pervane, boynuz), ana menüden seçilir
- [x] BUG: karakterlerde yerçekimi uygulanmıyordu (zıplayan/dalan havada kalıyordu) — düzeltildi

## Haftalık
- [x] Hafta 1 video fikirleri (`marketing/VIDEO_IDEAS.md`)
