extends Node
## Tiny TR/EN string table (autoload "I18n"). Use I18n.t("key") or I18n.t("key", [args]).

var lang := "en"

const S := {
	"title_sub": ["Evi şakalarla donat. Arkadaşların içine yürüsün.", "Booby-trap the house. Watch your friends walk right into it."],
	"name": ["İsim", "Name"],
	"practice": ["Antrenman (botlarla)", "Practice (with bots)"],
	"host": ["Oyun Kur", "Host Game"],
	"join": ["Katıl", "Join"],
	"ip": ["Adres (IP)", "Address (IP)"],
	"steam_host": ["Steam ile Kur (arkadaş davet et)", "Host on Steam (invite friends)"],
	"invite": ["Arkadaş Davet Et (Steam)", "Invite Friends (Steam)"],
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
	"setup_help": ["[Q/R] şaka seç  [Sol tık/F] yerleştir", "[Q/R] pick prank  [LMB/F] place"],
	"run_help_trapper": ["[1-9] uzaktan tetikle  [Tab] kamera  [WASD] kaydır", "[1-9] remote trigger  [Tab] camera  [WASD] pan"],
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
		l = "tr" if OS.get_locale_language() == "tr" else "en"
	lang = l


func t(key: String, args: Array = []) -> String:
	var row = S.get(key)
	var s: String = key if row == null else str(row[0 if lang == "tr" else 1])
	if args.size() > 0:
		return s % args
	return s
