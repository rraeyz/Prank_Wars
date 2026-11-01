# Prank Wars — PLAN

Bu dosya projenin görev listesidir. Her oturum bu dosyayı ve `PROGRESS.md`'yi okuyup ilk `[ ]` görevden devam eder.
İşaretler: `[x]` bitti · `[ ]` yapılacak · `[~]` kısmen / kullanıcı testi bekliyor · `[K]` sadece kullanıcı yapabilir.

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
- [ ] Saatlik devam tetikleyicisi
- [ ] Proje iskeleti (project.godot, autoload'lar, giriş tuşları)
- [ ] Ekransız test çalıştırıcı (`tests/run_tests.gd`)
- [ ] GitHub Actions: testler + Windows .exe derlemesi (artifact)

## Faz 1 — Oynanabilir prototip
- [ ] Ev haritası koddan (5 oda + bahçe, kapılar, mobilya, dolaplar)
- [ ] Karakter: hareket, zıplama, dalış, devrilme/kalkma, sallanan kollar, gözler
- [ ] Kamera: açılı takip + duvar şeffaflaşması; izleyici (kuran takım) kamerası
- [ ] Şakalar: muz kabuğu, kapı üstü kova, boya bombası
- [ ] Hazırlık modu: şaka seçme, hayalet önizleme, bütçe, yerleştirme kuralları
- [ ] Görevler: etkileşim (E basılı tut), taşıma görevleri
- [ ] Puanlama + zincir mantığı (saf sınıf, testli)
- [ ] Raunt / maç akışı (hazırlık → görev → tekrar → skor, roller değişir)
- [ ] HUD (süre, skor, görevler, bütçe, olay akışı, zincir yazısı)
- [ ] Botlar (koşucu + kurucu)
- [ ] Antrenman modu (sen + botlar)
- [ ] Ana menü + lobi
- [ ] Testler: puanlama, zincir, şaka tetikleme, botlu tam raunt
- [ ] İlk Windows .exe
- [K] **Kullanıcı testi 1:** oyna, arkadaşla oyna, güldünüz mü? (bkz. PROGRESS.md)

## Faz 2 — Çok oyunculu sağlamlık
- [ ] Ev sahibi yetkili model: istemci girdileri → host fizik → durum paketleri (20 Hz) + yumuşatma
- [ ] Lobi: isim, takım, renk, bot ekle/çıkar, başlat
- [ ] Bağlantı kopması / oyuncu ayrılması
- [ ] Ekransız iki süreçli ağ testi (host + istemci aynı makinede)
- [ ] GodotSteam: Steam lobisi + arkadaş daveti + Steam P2P (uygulama 480 ile test)
- [K] **Kullanıcı testi 2:** iki bilgisayarla online test

## Faz 3 — İçerik
- [ ] 14 şakanın tamamı (yağlı zemin, un torbası, osuruk minderi, boks eldiveni, bant, yay, bilyeler, konfeti, alarm, sahte kumanda, robot süpürge)
- [ ] 8 görev
- [ ] Tekrar kamerası (en iyi zincir, ağır çekim, filigran)
- [ ] Ses efektleri (sentez) + müzik
- [ ] Boya / un / su efektleri ve kalıcı lekeler

## Faz 4 — Cila
- [ ] Türkçe + İngilizce arayüz
- [ ] Ayarlar (ses, dil, tam ekran)
- [ ] Gamepad desteği
- [ ] CC0 mobilya modelleri (Kenney Furniture Kit) — erişim sorunu, bkz. PROGRESS
- [ ] Performans ve hata düzeltme turu
- [K] Arkadaş gruplarıyla 4–8 kişilik test

## Faz 5 — Steam'e hazırlık
- [ ] Steam sürümü (GodotSteam ile, appID ayarlanabilir)
- [ ] Mağaza metinleri ve tanıtım klasörü (`marketing/`)
- [K] Steamworks hesabı + $100 ödeme
- [K] Mağaza görselleri / fragman çekimi
- [ ] Demo yapılandırması (5 şaka)

## Haftalık
- [ ] Hafta 1 video fikirleri (`marketing/VIDEO_IDEAS.md`)
