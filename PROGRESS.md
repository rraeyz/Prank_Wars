# Prank Wars — PROGRESS

Her oturumun sonunda buraya kısa bir kayıt eklenir (en yeni en üstte).
Sonraki oturum: önce `PLAN.md`, sonra bu dosyanın en üstündeki kaydı oku.

## Ortam notları (bulut oturumu için)
- Godot 4.4.1 Linux: `/opt/godot/Godot_v4.4.1-stable_linux.x86_64` (`godot` olarak link). Container silinirse yeniden kur:
  `curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip`
- Export şablonları: `~/.local/share/godot/export_templates/4.4.1.stable/` (aynı release sayfasından `..._export_templates.tpz`).
- Testler: `godot --headless --path . -s res://tests/run_tests.gd`
- Ekran görüntüsü için: `xvfb-run -a godot --path . --rendering-driver opengl3 ...`
- kenney.nl ve api.github.com bu ortamdan 403 veriyor; github.com release indirmeleri çalışıyor.

---

## Oturum 1 — 2026-11-01
- Başlangıç: repo boştu. PLAN.md / PROGRESS.md oluşturuldu.
