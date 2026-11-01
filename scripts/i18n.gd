extends Node
## Tiny TR/EN string table (autoload "I18n"). Use I18n.t("key") or I18n.t("key", [args]).

var lang := "en"
const EXTRA := preload("res://scripts/i18n_extra.gd")
const ALL_LANGS := ["tr", "en", "es", "pt", "de", "fr", "ru"]
const LANG_NAMES := ["Türkçe", "English", "Español", "Português", "Deutsch", "Français", "Русский"]

const S := {
	"title_sub": ["Evi şakalarla donat. Arkadaşların içine yürüsün.", "Booby-trap the house. Watch your friends walk right into it."],
	"name": ["İsim", "Name"],
	"practice": ["Antrenman (botlarla)", "Practice (with bots)"],
	"host": ["Oyun Kur", "Host Game"],
	"join": ["Katıl", "Join"],
	"ip": ["Adres (IP)", "Address (IP)"],
	"steam_host": ["Steam ile Kur (arkadaş davet et)", "Host on Steam (invite friends)"],
	"invite": ["Arkadaş Davet Et (Steam)", "Invite Friends (Steam)"],
	"sandbox": ["Kum Havuzu (tuzak dene)", "Sandbox (test your traps)"],
	"phase_sandbox": ["KUM HAVUZU", "SANDBOX"],
	"sandbox_help": ["[Q/R] seç  [Sol tık] koy  [T] uzaktan şakaları patlat  [Backspace] tuzakları yenile  [Delete] hepsini sil  [E] görev/aç", "[Q/R] pick  [LMB] place  [T] fire remote pranks  [Backspace] re-arm traps  [Delete] clear all  [E] chore/open"],
	"tips_trap": [["İpucu: Görev yerlerinin hemen önüne kur — herkes oraya gelmek zorunda.", "Tip: trap right in front of chore spots — everyone has to go there."],
		["İpucu: Kapılar herkesin geçtiği yer. Kova + kapının arkasına muz = zincir!", "Tip: doors are where everyone walks. Bucket + banana behind the door = chain!"],
		["İpucu: Buzdolabına boya bombası koy, sandviç görevi varsa kesin açılır.", "Tip: paint bomb in the fridge — the sandwich chore will open it."],
		["İpucu: Yapışkan bant + üstüne un torbası: rakip kaçamaz.", "Tip: sticky tape + flour sack above it: they can't escape."],
		["İpucu: Uçan koşucu başka koşucuya çarparsa zincir büyür.", "Tip: a flying runner that hits another runner grows the chain."]],
	"tips_run": [["İpucu: Yerdeki tuzaklar ancak yakınına gelince görünür. Yavaş git!", "Tip: floor traps only show up when you're close. Go slow!"],
		["İpucu: Görünen tuzağın yanında E'yi basılı tut: etkisiz bırak, +10 puan.", "Tip: hold E next to a visible trap to disarm it: +10."],
		["İpucu: Alarm çalarsa hemen bul ve sustur, yoksa rakip puan alır.", "Tip: if the alarm rings, find and stop it or they score."],
		["İpucu: Görevler takımca yapılır, ayrılın!", "Tip: chores are shared by your team — split up!"]],
	"tips_warm": [["Isınma: arkadaşlarına dalış yap (Shift), topu kap ve fırlat!", "Warm-up: dive into your friends (Shift), grab the ball and throw it!"]],
	"credits": ["Krediler", "Credits"],
	"credits_text": ["Prank Wars\nTasarım, test ve tanıtım: idris\nKod: Claude (Anthropic) ile birlikte\n\nMotor: Godot Engine (MIT lisansı)\nModeller, sesler ve müzik koddan üretildi.\nSteam bağlantısı: GodotSteam (MIT)", "Prank Wars\nDesign, testing and marketing: idris\nCode: made together with Claude (Anthropic)\n\nEngine: Godot Engine (MIT license)\nModels, sounds and music are generated in code.\nSteam integration: GodotSteam (MIT)"],
	"shot_saved": ["Ekran görüntüsü kaydedildi: %s", "Screenshot saved: %s"],
	"rej_in_match": ["Maç devam ediyor, bitince tekrar dene.", "A match is in progress, try again when it ends."],
	"rej_full": ["Oda dolu (en fazla 8 kişi).", "The room is full (max 8)."],
	"how": ["Nasıl Oynanır", "How to Play"],
	"how_text": ["1) İki takım sırayla oynar.\n2) KURANLAR 60 sn'de evi şakalarla donatır (Q/R seç, Sol tık koy). Bütçe 15.\n3) KOŞUCULAR 100 sn'de 3 ev işini yapar (E basılı tut). Tuzaklar yaklaşınca görünür!\n4) Kuranlar izler, uzaktan şakaları 1-9 / Sol tık ile patlatır.\n5) Bir şaka diğerini tetiklerse ZİNCİR: her halka puanı ikiye katlar (10-20-40-80).\n6) Koşucular: görev +15, tuzağı etkisiz bırakma +10. Kuranlar: şaka + kirlilik puanı.\n\nShift: dalış · Space: zıpla · E: al/aç/görev · Sol tık: fırlat · F9: ekran görüntüsü · Esc: menü", "1) Two teams take turns.\n2) TRAPPERS get 60 s to rig the house (Q/R pick, LMB place). Budget 15.\n3) RUNNERS get 100 s for 3 chores (hold E). Traps only show up when you're close!\n4) Trappers watch and fire remote pranks with 1-9 / LMB.\n5) One prank setting off another is a CHAIN: every link doubles the points (10-20-40-80).\n6) Runners: chore +15, disarm +10. Trappers: pranks + mess points.\n\nShift: dive · Space: jump · E: grab/open/chore · LMB: throw · F9: screenshot · Esc: menu"],
	"intro_trap": ["%s KURUYOR — diğer takım bahçede bekliyor", "%s IS TRAPPING — the other team waits in the garden"],
	"settings": ["Ayarlar", "Settings"],
	"quit": ["Çıkış", "Quit"],
	"back": ["Geri", "Back"],
	"lobby": ["Lobi", "Lobby"],
	"switch_team": ["Takım değiştir", "Switch team"],
	"add_bot": ["Bot ekle", "Add bot"],
	"remove_bot": ["Bot çıkar", "Remove bot"],
	"start": ["Başlat", "Start"],
	"leave": ["Ayrıl", "Leave"],
	"rounds": ["Raunt", "Rounds"],
	"waiting_host": ["Ev sahibinin başlatması bekleniyor...", "Waiting for the host to start..."],
	"connecting": ["Bağlanıyor...", "Connecting..."],
	"conn_failed": ["Bağlanılamadı.", "Could not connect."],
	"host_failed": ["Sunucu açılamadı (port kullanımda olabilir).", "Could not host (port may be in use)."],
	"disconnected": ["Bağlantı koptu.", "Disconnected."],
	"team_0": ["Turuncu Takım", "Orange Team"],
	"team_1": ["Mavi Takım", "Blue Team"],
	"lang": ["Dil", "Language"],
	"master": ["Ana ses", "Master volume"],
	"music": ["Müzik", "Music"],
	"sfx": ["Efektler", "Effects"],
	"fullscreen": ["Tam ekran", "Fullscreen"],
	"need_both_teams": ["Her takımda en az 1 oyuncu olmalı (bot ekleyebilirsin).", "Each team needs at least 1 player (add a bot)."],
	"host_info": ["Arkadaşların bu adrese bağlanır: %s  (port %d)", "Friends connect to: %s  (port %d)"],

	"phase_intro": ["Hazır ol!", "Get ready!"],
	"phase_setup": ["HAZIRLIK", "SETUP"],
	"phase_run": ["GÖREV", "CHORES"],
	"phase_replay": ["TEKRAR", "REPLAY"],
	"phase_score": ["RAUNT SONU", "ROUND OVER"],
	"phase_end": ["MAÇ SONU", "MATCH OVER"],
	"round_n": ["Raunt %d / %d", "Round %d / %d"],
	"you_trap": ["Sen KURUYORSUN: evi tuzakla!", "You are TRAPPING: rig the house!"],
	"you_run": ["Sen GÖREV yapıyorsun: bahçede bekle, sonra görevleri bitir!", "You do the CHORES: wait in the garden, then finish the chores!"],
	"runners_enter": ["Koşucular içeri giriyor!", "Runners are coming in!"],
	"budget": ["Bütçe", "Budget"],
	"tasks": ["Görevler", "Chores"],
	"setup_help": ["[Q/R / tekerlek] şaka seç  [Sol tık / F] fareyle gösterdiğin yere koy", "[Q/R / wheel] pick prank  [LMB / F] place where you point"],
	"run_help_trapper": ["[1-9] veya [Sol tık] uzaktan şakayı patlat  [Tab] kamera  [WASD] kaydır", "[1-9] or [LMB] fire a remote prank  [Tab] camera  [WASD] pan"],
	"run_help_runner": ["[E] basılı tut: görev / aç / etkisiz bırak  [Space] zıpla  [Shift] dalış", "[E] hold: chore / open / disarm  [Space] jump  [Shift] dive"],
	"warmup_help": ["Bahçede ısın: [Shift] dalış, [E] eşya al, [Sol tık] fırlat", "Warm up: [Shift] dive, [E] grab, [LMB] throw"],
	"no_budget": ["Bütçe yetmiyor!", "Not enough budget!"],
	"cant_place": ["Buraya konmaz", "Can't place here"],
	"winner": ["%s KAZANDI!", "%s WINS!"],
	"draw": ["BERABERE!", "IT'S A DRAW!"],
	"best_prank": ["En iyi şaka", "Best prank"],
	"back_to_lobby": ["Lobiye dön", "Back to lobby"],
	"to_menu": ["Ana menü", "Main menu"],
	"resume": ["Devam", "Resume"],
	"wishlist": ["Steam'de istek listene ekle!", "Wishlist on Steam!"],
	"chain": ["ZİNCİR x%d!  +%d", "CHAIN x%d!  +%d"],
	"alarm_ring": ["ALARM! Saati bul ve sustur!", "ALARM! Find the clock and stop it!"],
	"spectate": ["İzliyorsun: %s", "Watching: %s"],
	"overview": ["Genel görünüm", "Overview"],

	"act_hold": ["Basılı tut", "Hold"],
	"act_open": ["Aç", "Open"],
	"act_disarm": ["Etkisiz bırak", "Disarm"],
	"act_grab": ["Al", "Grab"],
	"act_throw": ["Fırlat", "Throw"],

	"feed_prank": ["%s → %s  +%d", "%s → %s  +%d"],
	"feed_task": ["%s görevi bitti  +%d", "%s chore done  +%d"],
	"feed_disarm": ["%s bir %s etkisiz bıraktı  +%d", "%s disarmed a %s  +%d"],
	"feed_mess": ["Kirlilik puanı  +%d", "Mess bonus  +%d"],
	"feed_alarm_fail": ["Alarm susturulamadı  +%d", "Alarm never stopped  +%d"],
	"feed_bump": ["Çarpışma! %s", "Bump! %s"],

	"p_banana": ["Muz kabuğu", "Banana peel"],
	"p_bucket": ["Kapı kovası", "Door bucket"],
	"p_paint": ["Boya bombası", "Paint bomb"],
	"p_oil": ["Yağlı zemin", "Oil slick"],
	"p_flour": ["Un torbası", "Flour sack"],
	"p_whoopee": ["Osuruk minderi", "Whoopee cushion"],
	"p_glove": ["Boks eldiveni", "Boxing glove"],
	"p_tape": ["Yapışkan bant", "Sticky tape"],
	"p_spring": ["Dev yay", "Giant spring"],
	"p_marbles": ["Bilyeler", "Marbles"],
	"p_confetti": ["Konfeti topu", "Confetti cannon"],
	"p_alarm": ["Alarmlı saat", "Alarm clock"],
	"p_fake_remote": ["Sahte kumanda", "Fake remote"],
	"p_vacuum": ["Robot süpürge", "Robot vacuum"],
	"p_bump": ["Çarpışma", "Bump"],

	"pl_floor": ["yere", "floor"],
	"pl_door": ["kapıya", "door"],
	"pl_container": ["dolaba", "cupboard"],
	"pl_ceiling": ["tavana", "ceiling"],
	"pl_surface": ["herhangi bir yüzeye", "any surface"],
	"pl_task": ["görev eşyasına", "chore item"],
	"tr_remote": ["uzaktan", "remote"],

	"t_remote": ["TV kumandasını bul", "Find the TV remote"],
	"t_sandwich": ["Sandviç yap", "Make a sandwich"],
	"t_shower": ["Duş al", "Take a shower"],
	"t_bed": ["Yatağı topla", "Make the bed"],
	"t_trash": ["Çöpü çıkar", "Take out the trash"],
	"t_cat": ["Kediyi besle", "Feed the cat"],
	"t_laundry": ["Çamaşırları as", "Hang the laundry"],
	"t_plants": ["Çiçekleri sula", "Water the plants"],

	"s_remote_spot": ["Kumandayı al", "Grab remote"],
	"s_fridge": ["Buzdolabını aç", "Open fridge"],
	"s_counter": ["Sandviç yap", "Make sandwich"],
	"s_shower": ["Duş al", "Shower"],
	"s_bed": ["Yatağı topla", "Make bed"],
	"s_trash_bag": ["Çöp torbasını al", "Grab trash bag"],
	"s_trash_bin": ["Çöpe at", "Bin it"],
	"s_cat_cabinet": ["Mamayı al", "Get cat food"],
	"s_cat_bowl": ["Kediyi besle", "Feed cat"],
	"s_laundry": ["Sepeti al", "Grab basket"],
	"s_clothesline": ["Çamaşırları as", "Hang laundry"],
	"s_plant_a": ["Çiçeği sula", "Water plant"],
	"s_plant_b": ["Çiçeği sula", "Water plant"],
	"s_container": ["Aç", "Open"],
}


func _ready() -> void:
	set_lang(str(Config.settings.get("lang", "")))


func set_lang(l: String) -> void:
	if l == "":
		l = OS.get_locale_language()
	lang = l if l in ALL_LANGS else "en"


func tip(key: String, i: int) -> String:
	var rows: Array = S.get(key, [])
	if rows.is_empty():
		return ""
	var row: Array = rows[i % rows.size()]
	return str(row[0 if lang == "tr" else 1])


func t(key: String, args: Array = []) -> String:
	var row = S.get(key)
	var s: String = key if row == null else str(row[0 if lang == "tr" else 1])
	var ei: int = EXTRA.LANGS.find(lang)
	if ei >= 0 and EXTRA.S.has(key):
		s = str(EXTRA.S[key][ei])
	if args.size() > 0:
		return s % args
	return s
