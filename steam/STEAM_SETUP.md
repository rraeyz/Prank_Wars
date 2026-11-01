# Steam kurulumu (Steamworks hesabı açıldıktan sonra)

Sunucu kirası yok: odalar, eşleşme ve bağlantı Steam'in ücretsiz altyapısıyla (lobi + P2P relay) çalışır.

## 1. Uygulama
1. Steamworks'te uygulamayı oluştur ($100). Uygulama numarasını (AppID) not et.
2. CI'daki `echo 480 > build/win/steam_appid.txt` satırında 480 yerine AppID'yi yaz (480 = Valve'ın test uygulaması).

## 2. Odalar (arkadaşsız oyuncular için)
- Kod hazır: "Herkese açık oda kur" ve "Oda bul". Ek ayar gerekmez.
- Aynı oyun sürümündekiler birbirini görür (eski sürümler listelenmez).

## 3. Kozmetik mağazası (Steam Inventory Service)
1. Steamworks > Uygulama Yönetimi > **Inventory Service**'i aç.
2. `steam/itemdefs.json` dosyasındaki `appid` alanını doldur ve yükle. Fiyatlar `price_category` ile ("1;VLV100" ≈ 1 USD; Steam yerel fiyatı otomatik hesaplar).
3. Steamworks > **Item Store**'u aç. Oyun içinde Dolap'ta kilitli eşyada "Satın al" düğmesi Steam ödeme penceresini açar.
4. `900` numaralı "playtime generator" oynadıkça bedava eşya düşürür (haftada en fazla 1).
- Rastgele paralı kutu (loot box) yok: bazı ülkelerde kumar sayılıyor. Her eşya doğrudan, fiyatı görünerek satılır.
- Not: Oyun şu an satın alınan eşyayı istemcinin söylemesine güveniyor (sadece görünüş). İleride Steam envanter imzası doğrulanabilir.

## 4. Başarımlar (Achievements)
Steamworks > Stats & Achievements'ta şu kimliklerle (API Name) oluştur; oyun aynı adlarla açar:
FIRST_PRANK, CHAIN_3, CHAIN_5, GHOSTLY, CAT_HERDER, WINNER, BOMB_SQUAD, CHORE_MASTER, REGULAR, LEVEL_10.
Oyun içi "Başarımlar" ekranı Steam olmadan da çalışır.

## 5. Twitch modu
Steam gerekmez. Ayarlar > Twitch: kanal adını yaz, "İzleyiciler şaka göndersin"i işaretle.
İzleyiciler !muz !un !konfeti !deprem !kedi !osuruk (veya İngilizce !banana ...) yazar; 25 sn'de bir en çok oy alan şaka yayıncıya gelir.
Puanı değiştirmez, sadece kaos. Odayı yayıncı kurmalı (etkiler kurucu bilgisayarda hesaplanır).
