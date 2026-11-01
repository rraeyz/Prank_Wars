# Prank Wars — Oyun Tasarım Raporu

1 Kasım 2026 · idris

Prank Wars, iki takımın aynı evde sırayla birbirine şaka kurduğu, 2–8 kişilik, low-poly 3D bir online fizik komedisi. Hedef: $5 fiyatla dünya pazarı, 2 haftada oynanabilir prototip, yaklaşık 10 haftada Steam'e hazır sürüm.

## Künye

Oyun tek cümleyle: **"Evi şakalarla donat, rakip takım içeri girsin, en komik tuzağı kuran kazansın."**

| Özellik | Karar |
| --- | --- |
| Tür | Online parti / fizik komedisi, takımlar arası rekabet |
| Oyuncu | 2–8 kişi (1v1, 2v2, 3v3, 4v4) |
| Platform | Steam (Windows); sonra Steam Deck uyumu |
| Fiyat | $5 (Türkiye için Steam'in bölgesel fiyat önerisi) |
| Oturum | Bir raunt ~4,5 dakika; bir maç 4 raunt, her takım 2 kez kurar (~18 dakika) |
| Motor | Godot 4 (ücretsiz, açık kaynak) |
| Görsel | Low-poly 3D, parlak renkler, oyuncak gibi karakterler |
| Kamera | Üçüncü şahıs |
| Dil | Neredeyse metinsiz; arayüz Türkçe + İngilizce |
| Ekip | 2 kişi: tasarım, test, içerik ve tanıtım sende; kodun büyük kısmı Claude'da |
| Hedef kitle | Discord'da arkadaş grubuyla oynayan 15–30 yaş oyuncular ve onların izlediği yayıncılar |

## Neden bu oyun

Tek kişilik hikayeli bir oyunu yayında izleyen kişi oyunu izleyerek tüketir. Prank Wars ise izleyiciye "ben bundan daha iyisini kurardım" dedirtmek için tasarlandı. Yayınlardan satış getiren oyunların beş ortak özelliği ve bizdeki karşılıkları:

| Kural | Prank Wars'ta karşılığı |
| --- | --- |
| Arkadaşlarla oynanır | 2–8 kişilik takımlar. Bir izleyici, arkadaş grubuna da aldırır: 1 izleyici = 2–4 satış |
| Her oyun farklı geçer | Şakaları oyuncular kuruyor, fizik her seferinde farklı sonuç veriyor |
| 5 saniyede anlaşılır | "Tuzak kur, rakip içeri girsin" — dil gerektirmiyor |
| Ucuz | $5; dört arkadaşın "hadi alalım" diyebileceği fiyat |
| Klip üretir | Her rauntun sonunda en iyi şakanın ağır çekim tekrarı, tek tuşla kaydedilip paylaşılıyor |

En önemli fark yaratıcılık: izleyici yayıncının kurduğu tuzağı görüp kendi zincirini kurmak istiyor. Bu, oyunun izlenip bitmesini engelliyor.

## Oyun döngüsü

Bir maç 4 raunt sürer ve her takım 2 kez şaka kurar, 2 kez yakalanır; bir raunt yaklaşık 4,5 dakika.

```
[Raunt başlar]       →  [Hazırlık · 90 sn]       →  [Görev · 2,5 dk]        →  [Tekrar ve puan]
 3 görev rastgele        A takımı 15 puanla          B görevleri yapar,          En iyi şaka
 seçilir                 şaka kurar                  A uzaktan tetikler          ağır çekimde
      ↑                                                                               |
      └──────────── sonraki raunt · roller değişir (A ↔ B) ──────────────────────────┤
                                                                                      ↓ (4. raunttan sonra)
                                                                                 [Maç sonu]
                                                                                 En çok puan kazanır
```

Hazırlıkta kuran takım serbest kamerayla evi gezip şakaları yerleştirir; görev aşamasında karşı takım eve girer ve kuran takım izleyip uzaktan tetiklemeli şakaları doğru anda patlatır.

## Şaka listesi

İlk sürümde 14 şaka var; prototip bunlardan sadece 3'üyle (muz, kova, boya bombası) başlıyor. Her şakanın bir maliyeti var ve takımın hazırlık bütçesi sınırlı (bkz. Puanlama).

| Şaka | Nereye kurulur | Tetiklenme | Etkisi | Maliyet |
| --- | --- | --- | --- | --- |
| Muz kabuğu | Yer | Basınca | Kayıp düşer (ragdoll) | 1 |
| Yağlı zemin | Yer, 2×2 m | Basınca | Uzun kayma, çarpışma zinciri başlatır | 2 |
| Kapı üstünde su kovası | Kapı | Kapı açılınca | Islanır, 3 sn yavaşlar | 2 |
| Un torbası | Tavan | Uzaktan, butonla | Bembeyaz olur, görüşü azalır | 2 |
| Boya bombası | Dolap, buzdolabı, çekmece | Açılınca | Renkli boya; "kirlilik" puanı | 3 |
| Osuruk minderi | Koltuk, sandalye | Oturunca | Ses + kahkaha; rakip panik olur | 1 |
| Yaylı boks eldiveni | Dolap, kutu | Açılınca | Geri savrulur | 3 |
| Yapışkan bant | Yer, kapı eşiği | Basınca | 3 sn yapışır | 2 |
| Dev yay | Yer, halının altı | Basınca | Havaya fırlatır | 4 |
| Bilyeler | Merdiven | Basınca | Merdivenden yuvarlanır | 3 |
| Konfeti topu | Herhangi bir yüzey | Uzaktan, butonla | Ekranı kaplar, kafa karıştırır | 1 |
| Alarmlı saat | Gizli bir yer | Zamanlı | Ses; rakip bulmazsa puan kaybeder | 1 |
| Sahte kumanda | Görev eşyasının yerine | Alınınca | Elinde patlar (boya) | 3 |
| Robot süpürge | Yer, serbest dolaşır | Sürekli | Oyuncuyu iter, diğer şakaları tetikler | 4 |

Tetiklenme iki türlü: rakip basarsa ya da açarsa kendiliğinden çalışır, "uzaktan" olanları ise kuran takım doğru anda bir tuşla tetikler. Uzaktan tetikleme zamanlama becerisi istediği için şakayı izleyen kişinin de dikkatini tutar.

## Zincirleme şakalar ve puanlama

Puan, rakibi ne kadar ve ne kadar yaratıcı şekilde rezil ettiğine göre verilir. Amaç çok tuzak değil, iyi kurulmuş tuzak.

**Hazırlık bütçesi:** Her takım raunt başına 15 puan harcar. Pahalı şakalar güçlü, ama hepsini birden alamazsın.

**Puan kaynakları:**

- Tutan her şaka: 10 puan
- Zincir bonusu: bir şaka başka bir şakayı tetiklerse, zincirdeki her ek halka puanı ikiye katlar (1 halka 10, 2 halka 20, 3 halka 40...)
- Kirlilik: rakibin üstünün yüzde kaçı boya, un veya suyla kaplıysa o kadar puan
- Görev cezası: rakip görevlerini süre bitmeden tamamlarsa her görev için rakibe 15 puan
- Bulunan şaka: rakip bir şakayı tetiklemeden bulup etkisiz hale getirirse o puan rakibe geçer

**Zincir örneği:** Rakip muz kabuğuna basar → kayarak masaya çarpar → masadaki bilyeler merdivene dökülür → merdivendeki takım arkadaşı yuvarlanır → aşağıda açık duran kovaya düşer. 4 halkalı zincir = 80 puan.

Zincir bonusu oyunun kalbi: yayıncının kurduğu büyük zincir hem en komik klibi hem de izleyicinin "ben de deneyeceğim" dediği anı üretiyor.

## Görevler

Görevler, rakibi evin her yerine girmeye zorlar; böylece kimse kapıda bekleyip tuzaklardan kaçamaz. Her raunt başında 3 görev rastgele seçilir ve kuran takım bunları hazırlık aşamasında görür.

| Görev | Nerede | Neden şakaya açık |
| --- | --- | --- |
| TV kumandasını bul | Salon | Kumanda sahte olabilir, koltuk osuruk minderli olabilir |
| Sandviç yap | Mutfak | Buzdolabı, çekmeceler ve tezgah tuzaklanabilir |
| Duş al | Banyo | Dar alan, kaygan zemin, kapı kovası |
| Çamaşırları as | Balkon | Yay, bilye, yukarıdan düşen un |
| Kediyi besle | Koridor + mutfak | Uzun yürüyüş, yol boyu tuzak |
| Sigortayı aç | Bodrum | Karanlık; alarm ve konfeti için ideal |
| Çöpü dışarı çıkar | Mutfak → bahçe | Evin bir ucundan diğerine taşıma |
| Yatağı topla | Yatak odası | Yorganın altı gizli şaka yeri |

Görev süresi 2,5 dakika. Rakip ne kadar çok görevi bitirirse, şaka kuran takım o kadar puan kaybeder.

## Modlar

Çıkışta tek mod var: online takım maçı. Diğerleri ilk sürüm tutarsa eklenecek.

| Mod | Ne zaman | Açıklama |
| --- | --- | --- |
| Online takım maçı (1v1–4v4) | Çıkışta | Steam arkadaş daveti ve lobi kodu; 4 raunt, roller her raunt değişir |
| Antrenman evi | Çıkışta | Tek başına şaka kurup kendi tuzağını deneme alanı; zincir denemek için |
| Yapay zekâ rakip | Çıkıştan sonra | Arkadaşı olmayan oyuncu için tek kişilik mod |
| Twitch sohbet modu | Çıkıştan sonra | İzleyiciler oylamayla yayıncıya rastgele bir şaka gönderir |
| Yeni evler | Çıkıştan sonra | Okul, ofis, düğün salonu; ücretsiz güncelleme olarak |

Çıkışta tek bir ev haritası olacak: 2 katlı, 7 oda (salon, mutfak, banyo, yatak odası, koridor, bodrum, balkon) ve bahçe.

## Kamera, kontroller ve his

Oyunun komedisi karakterin nasıl düştüğüne bağlı; bu yüzden ilk iki hafta sadece bu his üzerinde çalışılacak.

- **Kamera:** Üçüncü şahıs, omuz üstünden. Hazırlık aşamasında kamera serbest uçarak şaka yerleştirme moduna geçer.
- **Kontroller:** Klavye-fare ve gamepad. Hareket, zıplama, eşya alma/atma, şaka yerleştirme, uzaktan tetikleme. Toplam 6 tuş.
- **Ragdoll:** Şakaya yakalanan karakter 1,5–3 saniye bez bebek gibi savrulur, sonra kendi kalkar. Bu süre boyunca kontrol oyuncuda değildir.
- **Abartılı fizik:** Yerçekimi ve savrulma kuvvetleri gerçekten güçlü ayarlanır; gerçekçilik değil komedi hedeflenir.
- **Tekrar kamerası:** Raunt sonunda en yüksek puanlı şaka ağır çekimde, en iyi açıdan tekrar gösterilir. Tek tuşla 10 saniyelik video veya GIF olarak kaydedilir.
- **Ses:** Her şakanın kendine has bir sesi ve karakterin abartılı bir tepki sesi var (çığlık, "aaah", kahkaha); dil gerektirmez.

## Görsel ve ses tarzı

Az poligonlu, parlak renkli, oyuncak gibi bir dünya; model çizmeden, hazır ücretsiz paketlerle kurulacak.

- **Modeller:** Kenney, Quaternius ve KayKit'in low-poly mobilya, ev ve karakter paketleri. Bu paketlerin çoğu CC0 lisanslı, yani ticari oyunda ücretsiz kullanılabilir. Her paketin lisansı kullanmadan önce tek tek kontrol edilecek.
- **Karakterler:** Yuvarlak, büyük kafalı, yüzsüz ya da basit yüzlü figürler. Her oyuncunun rengi farklı; boya ve un üzerlerinde net görünsün diye.
- **Renkler:** Ev pastel tonlarda, şakalar ve boya ise doygun ve parlak. Boyanın her yere bulaşması görsel kimliğin parçası.
- **Efektler:** Su sıçraması, un bulutu, konfeti, boya lekeleri. Lekeler kalıcı: raunt sonunda ev ne kadar dağınıksa o kadar komik görünür.
- **Müzik ve ses:** Hafif, şakacı bir müzik; ücretsiz veya uygun fiyatlı lisanslı kütüphanelerden. Ses efektleri de aynı şekilde.

## Teknik mimari

Fizik tek bir bilgisayarda hesaplanır, diğerleri sadece sonucu gösterir. Bu, çok oyunculu fizik oyunlarındaki en büyük riski (her ekranda farklı şey olmasını) ortadan kaldırmak için seçildi.

| Parça | Karar | Neden |
| --- | --- | --- |
| Motor | Godot 4 | Ücretsiz, hafif, Steam'e ve Steam Deck'e çıktı alıyor |
| Fizik | Godot 4'ün 3D fizik motoru (gerekirse Jolt) | Ragdoll ve çarpışmalar için yeterli |
| Ağ modeli | Ev sahibi (host) yetkili | Lobiyi kuran oyuncunun bilgisayarı fiziği hesaplar; diğerleri kontrollerini gönderir, sonucu alır |
| Bağlantı | Steam lobileri ve Steam P2P (GodotSteam eklentisi) | Sunucu kirası yok, NAT sorunlarını Steam çözüyor |
| Senkronizasyon | Saniyede 20–30 durum güncellemesi + aradaki kareler için yumuşatma | Gecikmede bile akıcı görünüm |
| Sesli sohbet | Oyunda yok; oyuncular Discord kullanır | En zor parçayı hiç yazmıyoruz |
| Tekrar kamerası | Son 10 saniyenin durumları bellekte tutulur, raunt sonunda yeniden oynatılır | Video kaydı gerektirmez, hafif |
| Testler | Godot ekransız (headless) modda otomatik testler | Puanlama, zincir ve senkronizasyon hatalarını erken yakalar |

Son test her zaman iki gerçek bilgisayarla yapılacak; otomatik testler ağ gecikmesini tam taklit edemez.

## Rakipler ve farkımız

Web aramasında iki takımın sırayla birbirine şaka kurduğu bir oyun bulunamadı; benzerler ya tek kişinin savunduğu evi, ya da öldürücü tuzakları konu alıyor.

| Oyun | Ne yapıyor | Bizden farkı |
| --- | --- | --- |
| [Bandit Trap](https://store.steampowered.com/app/3732550) | 3'e 1: bir oyuncu tuzaklı evi savunur, üçü soymaya çalışır. 2026 ilk çeyrekte çıkması planlanıyordu | Asimetrik ve soygun temalı; bizde iki eşit takım ve şaka/kirlilik puanı var |
| Trapper's Delight | 2–4 kişi birbirine ölümcül tuzak parkuru kurar. Online oyuncu bulmak zor olduğu belirtiliyor | Ölüm ve parkur; bizde şiddetsiz şaka, ev ve görevler |
| [Trap House](https://www.dekudeals.com/items/trap-house) | 2016; perili evde 1–8 kişilik öldürme yarışı | Eski ve korku/ölüm temalı |
| The Prank Bros | 1–8 kişilik parti oyunu, beceriler ve silahlar | Adı benzer ama savaş oyunu; tuzak kurma yok |
| [Hyde's Haunt & Seek](https://www.vgdb.co/games/hydes-haunt-seek) | Hayaletler bir arayanı korkutur | Saklambaç; tuzak ve zincir yok |

**Farkımız üç maddede:** şiddetsiz şaka teması (her yaşa ve yayıncıya uygun), sırayla kurma ve yakalanma (her oyuncu iki rolü de yaşar), zincir bonusu ve otomatik tekrar klibi.

## Mağaza ve tanıtım metinleri

Aşağıdaki metinler Steam sayfasına ve yayıncılara gönderilecek mesaja doğrudan kopyalanabilir. İngilizcesi ana metin, Türkçesi Türkiye sayfası için.

### Steam kısa açıklama (İngilizce)

> Booby-trap the house. Watch your friends walk right into it. Prank Wars is a chaotic 2–8 player physics comedy where two teams take turns rigging a home with pranks — and the best chain reaction wins.

### Steam kısa açıklama (Türkçe)

> Evi şakalarla donat, arkadaşlarının tam içine yürümesini izle. Prank Wars, iki takımın sırayla evi tuzakladığı 2–8 kişilik kaotik bir fizik komedisi. En iyi zincirleme şakayı kuran kazanır.

### Steam uzun açıklama (İngilizce)

> **Set it up. Watch it go wrong. Laugh until you can't breathe.**
>
> Two teams. One house. Ninety seconds to hide banana peels, buckets over doors, flour bombs and paint-loaded fridges. Then the other team has to do their chores — make a sandwich, take a shower, find the remote — while everything you built goes off.
>
> - **14 pranks** you can place anywhere and trigger at the perfect moment
> - **Chain reactions:** one slip knocks over the next trap — every extra link doubles your score
> - **Ragdoll physics** that make every fall a highlight
> - **Instant replays:** the best prank of each round, in slow motion, saved as a clip in one click
> - **1v1 up to 4v4** online with Steam friends
> - No blood, no violence — just a very, very messy house

### Yayıncıya gönderilecek mesaj (İngilizce)

> Subject: A prank game made for your stream — free key inside
>
> Hi [name],
>
> I'm a solo developer from Turkey and I made Prank Wars: two teams rig a house with pranks, then the other team walks in. Chain reactions, ragdoll falls and an auto slow-mo replay of the best prank every round. It plays best with 4–8 people, so it fits a community night.
>
> Here are keys for you and three friends: [keys]. A 30-second gameplay clip: [link].
>
> No pressure to cover it — I'd just love to see what chain you build.
>
> [your name]

### Yayıncıya gönderilecek mesaj (Türkçe)

> Konu: Yayının için yapılmış bir şaka oyunu — ücretsiz key içeride
>
> Merhaba [isim],
>
> Ben Erzurum'da üniversite okuyan, oyununu kendi yapan bir geliştiriciyim. Prank Wars'ta iki takım evi şakalarla donatıyor, sonra karşı takım içeri giriyor. Zincirleme şakalar, savrulan karakterler ve her rauntun en iyi şakasının ağır çekim tekrarı var. 4–8 kişiyle oynanınca en komik hali çıkıyor.
>
> Sana ve 3 arkadaşına key'ler: [key'ler]. 30 saniyelik oynanış videosu: [link].
>
> Yayınlaman zorunlu değil; sadece kuracağın zinciri görmek isterim.
>
> [adın]

## Pazarlama planı

Para harcanmadan yapılacak; amaç çıkıştan önce Steam'de olabildiğince çok "istek listesi" (wishlist) toplamak. Çıkış haftasındaki satışı en çok bu sayı belirler.

1. **TikTok, YouTube Shorts ve Instagram Reels (1. haftadan itibaren):** Haftada en az 3 kısa video. En komik düşme, en uzun zincir, "bu şakayı nasıl kurdum" videoları. İlk 2 haftadaki videoların izlenmesi fikrin tutup tutmadığını gösteren ilk test.
2. **Steam sayfası (4. hafta civarı):** Sayfa erken açılır, böylece videolardan gelen ilgi istek listesine dönüşür. Kapak görseli, 5 ekran görüntüsü ve 30 saniyelik fragman gerekir.
3. **Reddit ve Discord:** r/IndieDev, r/indiegames ve co-op oyun topluluğunda geliştirme güncellemeleri. Oyunun kendi Discord sunucusu oyun arkadaşı bulma yeri olur.
4. **Ücretsiz demo ve Steam Next Fest:** Demo, tek ev ve 5 şakayla. Steam'in bir sonraki Next Fest'ine katılım; tarih ve kayıt koşulları Steamworks'te kontrol edilecek.
5. **Yayıncılar:** Demo ve çıkış öncesi orta boy (1.000–50.000 takipçi) co-op ve parti oyunu yayıncılarına key ("Yayıncıya gönderilecek mesaj" metni). Büyük yayıncılar orta boyların klipleri sayesinde fark eder.
6. **Oyun içi paylaşım:** Tekrar klibi kaydedilirken köşeye oyunun adı ve Steam bağlantısı eklenir; oyuncuların paylaştığı her klip reklam olur.

## Maliyet ve gelir

Zorunlu tek masraf Steam'in $100 ücreti; aylık $100–200 hedefi için ayda yaklaşık 40–80 kopya satış gerekiyor.

**Maliyet:**

- Steam Direct ücreti: $100 (oyun $1.000 satınca Steam geri öder)
- Modeller, motor, ağ altyapısı: $0 (ücretsiz paketler, Godot, Steam P2P)
- Müzik ve ses: $0–50

**Kopya başına kazanç (yaklaşık):** $5 fiyat, bölgesel indirimli fiyatlar ve iadelerle ortalama ~$4 satış; Steam'in %30 payından sonra eline yaklaşık **$2,5–3** kalır (vergi hariç).

| Senaryo | Toplam satış | Yaklaşık net gelir |
| --- | --- | --- |
| Kötü | 100 kopya | ~$275 |
| Orta | 1.000 kopya | ~$2.750 |
| İyi | 5.000 kopya | ~$13.750 |
| Çok iyi (bir yayıncı klibi patlarsa) | 30.000 kopya | ~$82.500 |

Rakamlar tahmini. Steam'deki indie oyunların yarısı ömür boyu $500 altında kalıyor; "kötü" senaryo gerçek bir olasılık. Yurt dışından gelen gelirin vergisi için bir mali müşavire danışılmalı.

## Yol haritası

10 haftada demo hazır; tam çıkış tarihi demonun ve istek listesinin durumuna göre 2027 başında belirlenecek.

| Hafta | Tarih | Aşama | İçerik |
| --- | --- | --- | --- |
| 1–2 | 2–15 Kasım | **Prototip** | Tek oda, 2 oyuncu, 3 şaka (muz, kova, boya bombası); kayma ve ragdoll hissi. İlk TikTok videosu |
| | | ◆ **Kapı: test grubu güldü mü?** | |
| 3–4 | 16–29 Kasım | Çekirdek oyun | Tam ev haritası, görevler, puanlama ve zincir bonusu. Steam lobisi ve iki bilgisayarlı ilk online test |
| | | ◆ Steam sayfası açılır ($100) | |
| 5–6 | 30 Kasım – 13 Aralık | İçerik | 14 şakanın tamamı, 8 görev, tekrar kamerası. Ses efektleri, müzik, su / un / boya efektleri |
| 7–8 | 14–27 Aralık | Cila ve test | Menüler, Türkçe ve İngilizce arayüz, hata düzeltmeleri. Arkadaş gruplarıyla 4–8 kişilik testler |
| | | ◆ Demo hazır | |
| 9–10 | 28 Aralık – 10 Ocak | Demo ve yayıncılar | Ücretsiz demo (tek ev, 5 şaka), yayıncılara key. İstek listesine göre çıkış tarihi kararı |

Plan okul dönemine göre esneyebilir; sıra değişmez. En önemli an 2. haftanın sonundaki test: prototip arkadaşları güldürmüyorsa içerik eklemeden önce mekanik değiştirilir.

## Riskler ve önlemler

En büyük risk teknik değil: oyunun yeterince komik olmaması. Bu yüzden her adım küçük bir prototip ve gerçek oyuncu testiyle ilerliyor.

| Risk | Etkisi | Önlem |
| --- | --- | --- |
| Oyun komik değil | Kimse paylaşmaz, satış olmaz | 2. haftada 2 kişilik prototipi arkadaşlarla test et; gülmüyorlarsa büyütme, değiştir |
| Çok oyunculu fizik senkronizasyonu bozuk | Ekranlarda farklı şeyler olur, oyun sinir bozucu olur | Ev sahibi yetkili model, erken ve sık iki bilgisayarlı test |
| Online oyuncu bulunamaması | Arkadaşı olmayan oyuncu oynayamaz | Discord sunucusu, antrenman evi; tutarsa yapay zekâ rakip |
| Videolar izlenmiyor | Steam'de istek listesi toplanmaz | 2–3 haftada farklı video türleri dene; hiçbiri tutmazsa fikri gözden geçir |
| İsim zaten alınmış | Steam'de karışıklık, marka sorunu | Sayfa açmadan önce Steam'de ve uygulama mağazalarında isim kontrolü |
| Model lisansı sorunu | Oyun mağazadan kaldırılabilir | Sadece lisansı açıkça ticari kullanıma izin veren paketler; listesi repoda tutulur |
| Zaman ve motivasyon | Proje yarım kalır | Haftalık hedefler, her hafta bir video; okul dönemine göre plan esnetilir |

## Açık sorular ve ilk adımlar

Kodlamaya başlamak için sadece ilk üç adım gerekli.

- [ ] GitHub'da `prank-wars` reposunu aç ve adını Claude'a yaz
- [ ] Bilgisayara Godot 4 kur
- [ ] Prototipi test edecek en az 1 arkadaş ve ikinci bir bilgisayar ayarla
- [ ] "Prank Wars" adının Steam'de ve mağazalarda boş olup olmadığını kontrol et (Claude yapacak)
- [ ] Kullanılacak model paketlerinin lisanslarını kontrol et (Claude yapacak)
- [ ] TikTok / YouTube hesabı aç: oyunun adıyla
- [ ] Steamworks geliştirici hesabı aç ve $100 ödemesini planla (4. hafta civarı)

**Açık sorular:**

- Bir maç 4 raunt mı olmalı, 6 mı? Prototip testinde karar verilecek.
- Steam mağaza adı "Prank Wars" mı olacak, alt başlıklı mı (örneğin "Prank Wars: House Rules")? İsim kontrolüne göre.
- Oyunun yayıncısı olarak hangi ad kullanılacak (kendi adın mı, stüdyo adı mı)?

## Kaynaklar

Rakip ve pazar bilgileri web aramasından alındı; sayfaların hepsi tek tek açılıp doğrulanmadı, Steam'in kendi aramasıyla tekrar kontrol edilecek.

- [Bandit Trap — Steam](https://store.steampowered.com/app/3732550)
- [Trap House — Deku Deals](https://www.dekudeals.com/items/trap-house)
- [Hyde's Haunt & Seek — VGDB](https://www.vgdb.co/games/hydes-haunt-seek)
- [Indie oyun gelirleri, ortanca $5–15 bin](https://www.steampageanalyzer.com/blog/indie-game-revenue-data)
- [Steam Next Fest Şubat 2026 öne çıkanları](https://indiegame.com/en/archives/22795)
- [TikTok üzerinden tutan indie oyunlar](https://everything-pr.com/indie-games-viral-tiktok)
- [Tür analizi 2026](https://pokeindie.com/blog/game-genre-study-2026-which-genres-are-worth-building)
