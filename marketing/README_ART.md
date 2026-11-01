# Mağaza görsellerini / fragmanı yeniden üretmek

Hepsi oyunun kendisinden üretilir (dış görsel yok). GPU'lu bir bilgisayarda çok daha hızlı ve güzel olur.

```bash
# 1) Steam kapsülleri + kütüphane görselleri (tek sahne, tüm boyutlar aynı karede)
godot --path . -- --capsule=marketing/steam_art

# 2) Fragman ham çekimi (4 harita, başlık kartları, ~2 dk ham; Movie Maker modu, gerçek zamandan bağımsız)
godot --path . --resolution 1920x1080 --fixed-fps 30 --write-movie build/trailer/raw.avi -- --trailer=build/trailer

# 3) Kurgu: en çok düşmenin olduğu anlar + 1 ağır çekim + müzik -> trailer.mp4 ve dikey trailer_vertical.mp4
python3 tools/trailer_edit.py build/trailer

# 4) Ekran görüntüleri (HUD'lu oyun içi): oyunda F9, ya da
godot --path . -- --keyart=marketing/steam_art
```

Linux sunucuda GPU yoksa: `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver vulkan ...`
(yazılım render, ~1.5 kare/sn).

Fragman her çekimde biraz farklı olur (botlar rastgele). Beğenmezsen 2–3 adımı tekrar çalıştır.
