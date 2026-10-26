#!/usr/bin/env python3
"""The AEW Fight Forever move library: every wrestler's signatures and
specials from the owner's compilation (gauntlet/refs/aew_ff_animation_review.md),
each move tagged to the wrestlers who use it.

    python3 game/tools/moves/build_ff_library.py

Writes, deterministically (same table, byte-identical output):
  game/resources/moves/ff/<move>.tres    one MoveDef per move
  game/resources/moves/ff_library.gd     FFMoveLibrary: wrestlers -> moves, move -> tags

A move Fight Forever uses for several wrestlers (Spinebuster 5: Cash, Jade,
Hobbs) is ONE move tagged to all of them, the way the game shares a numbered
variant. A move whose paired animation is not authored yet is in the library
but flagged unbuilt (FFMoveLibrary.is_built), so nothing in a match can pick
it; the animation batches fill them in family by family.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "resources" / "moves" / "ff"
LIB = ROOT / "resources" / "moves" / "ff_library.gd"

# id: (Fight Forever banner name, family, setup)
# setup: how the move starts -- front (facing, standing grapple), rear,
# running, seated / kneeling (opponent sat up or on his knees), ground
# (opponent lying), corner (opponent in the corner), top_rope, springboard,
# rope (rebound / slingshot off the ropes).
MOVES = {
    "cemetery_drive": ("Cemetery Drive", "driver", "front"),
    "snapmare_1": ("Snapmare 1", "takedown", "front"),
    "shining_wizard": ("Shining Wizard", "knee", "kneeling"),
    "ushigoroshi": ("Ushigoroshi", "backbreaker", "front"),
    "the_boom": ("The Boom", "knee", "seated"),
    "panama_sunrise_2": ("Panama Sunrise 2", "aerial", "top_rope"),
    "pop_up_powerbomb_1": ("Pop-Up Powerbomb 1", "powerbomb", "front"),
    "rope_fallaway_slam_moonsault": ("Rope Fallaway Slam Moonsault", "slam", "front"),
    "dead_eye": ("Dead Eye", "driver", "front"),
    "buckshot_lariat": ("Buckshot Lariat", "lariat", "springboard"),
    "backbreaker_final_cut_combo": ("Backbreaker/Final Cut Combo", "combo", "front"),
    "jawbreaker": ("Jawbreaker", "takedown", "front"),
    "brutalizer": ("Brutalizer", "submission", "ground"),
    "el_idolo_3": ("El Idolo 3", "submission", "ground"),
    "jay_kick_1": ("Jay Kick 1", "kick", "front"),
    "queen_slayer": ("Queen Slayer", "submission", "front"),
    "buckle_bomb": ("Buckle Bomb", "powerbomb", "front"),
    "weapon_x": ("Weapon X", "slam", "front"),
    "drill_claw": ("Drill Claw", "driver", "front"),
    "avalanche_drill_claw": ("Avalanche Drill Claw", "driver", "corner"),
    "sling_blade_3": ("Sling Blade 3", "neckbreaker", "running"),
    "fisherman_neckbreaker": ("Fisherman Neckbreaker", "neckbreaker", "front"),
    "lock_jaw_2": ("Lock Jaw 2", "submission", "ground"),
    "strong_stomp_2": ("Strong Stomp 2", "aerial", "ground"),
    "kick_combo": ("Kick Combo", "combo", "front"),
    "diving_headbutt_1": ("Diving Headbutt 1", "aerial", "top_rope"),
    "lebell_lock_2": ("LeBell Lock 2", "submission", "ground"),
    "cattle_mutilation": ("Cattle Mutilation", "submission", "ground"),
    "flying_single_leg_knee_strike_1": ("Flying Single Leg Knee Strike 1", "knee", "seated"),
    "spinebuster_5": ("Spinebuster 5", "spinebuster", "front"),
    "code_breaker_1": ("Code Breaker 1", "cutter", "front"),
    "code_breaker_3": ("Code Breaker 3", "cutter", "front"),
    "springboard_moonsault_3": ("Springboard Moonsault 3", "aerial", "springboard"),
    "diving_judas_effect": ("Diving Judas Effect", "strike", "top_rope"),
    "running_judas_effect": ("Running Judas Effect", "strike", "running"),
    "judas_effect": ("Judas Effect", "strike", "front"),
    "diving_frog_splash": ("Diving Frog Splash", "aerial", "top_rope"),
    "inverted_ddt_1": ("Inverted DDT 1", "ddt", "front"),
    "unprettier": ("Unprettier", "ddt", "front"),
    "spear_2": ("Spear 2", "spear", "running"),
    "sit_out_piledriver_6": ("Sit-Out Piledriver 6", "piledriver", "front"),
    "sole_food": ("Sole Food", "kick", "front"),
    "scoop_slam_2": ("Scoop Slam 2", "slam", "front"),
    "anaconda_vise": ("Anaconda Vise", "submission", "ground"),
    "gts_2": ("GTS 2", "knee", "front"),
    "cody_cutter_4": ("Cody Cutter 4", "cutter", "front"),
    "figure_four_leglock": ("Figure Four Leglock", "submission", "ground"),
    "tiger_driver_98": ("Tiger Driver '98", "driver", "front"),
    "cross_rhodes": ("Cross Rhodes", "driver", "front"),
    "code_red_2": ("Code Red 2", "powerbomb", "running"),
    "float_over_stunner": ("Float-Over Stunner", "stunner", "front"),
    "coffin_drop_1": ("Coffin Drop 1", "aerial", "top_rope"),
    "neck_crank": ("Neck Crank", "submission", "ground"),
    "sit_out_powerbomb_2": ("Sit-Out Powerbomb 2", "powerbomb", "front"),
    "brainbuster_1": ("Brainbuster 1", "suplex", "front"),
    "code_red_1": ("Code Red 1", "powerbomb", "running"),
    "final_reckoning": ("Final Reckoning", "driver", "front"),
    "sleeper_suplex": ("Sleeper Suplex", "suplex", "rear"),
    "spinning_back_fist": ("Spinning Back Fist", "strike", "front"),
    "falcon_arrow_3": ("Falcon Arrow 3", "suplex", "front"),
    "fireman_carry_backbreaker": ("Fireman Carry Backbreaker", "backbreaker", "front"),
    "katana": ("Katana", "knee", "front"),
    "tamashi_no": ("Tamashi No", "knee", "running"),
    "jaded": ("Jaded", "driver", "front"),
    "gourdbuster_4": ("Gourdbuster 4", "suplex", "front"),
    "twist_of_fate_1": ("Twist of Fate 1", "cutter", "front"),
    "swanton_bomb": ("Swanton Bomb", "aerial", "top_rope"),
    "the_meat_man_combo": ("The Meat Man Combo", "combo", "front"),
    "spin_doctor": ("Spin Doctor", "slam", "front"),
    "avalanche_torture_rack_bomb": ("Avalanche Torture Rack Bomb", "powerbomb", "corner"),
    "gotch_style_piledriver": ("Gotch Style Piledriver", "piledriver", "front"),
    "arm_trapped_elbow_strikes": ("Arm Trapped Elbow Strikes", "strike", "ground"),
    "bulldog_choke_2": ("Bulldog Choke 2", "submission", "front"),
    "avalanche_poison_rana": ("Avalanche Poison 'Rana", "hurricanrana", "corner"),
    "poison_rana_1": ("Poison 'Rana 1", "hurricanrana", "front"),
    "running_v_trigger_3": ("Running V-Trigger 3", "knee", "running"),
    "powerbomb_v_trigger_combo": ("Powerbomb/V-Trigger Combo", "combo", "front"),
    "snap_dragon_suplex_3": ("Snap Dragon Suplex 3", "suplex", "rear"),
    "snap_dragon_suplex_2": ("Snap Dragon Suplex 2", "suplex", "rear"),
    "running_v_trigger_1": ("Running V-Trigger 1", "knee", "running"),
    "v_trigger_1": ("V-Trigger 1", "knee", "front"),
    "one_winged_angel": ("One Winged Angel", "driver", "front"),
    "electric_chair_facebuster_1": ("Electric Chair Facebuster 1", "slam", "front"),
    "chokeslam_1": ("Chokeslam 1", "slam", "front"),
    "old_school_moonsault": ("Old School Moonsault", "aerial", "rope"),
    "black_out_1": ("Black Out 1", "driver", "front"),
    "black_out_2": ("Black Out 2", "driver", "front"),
    "fireman_carry_bomb_2": ("Fireman Carry Bomb 2", "powerbomb", "front"),
    "the_end": ("The End", "kick", "front"),
    "side_effect_1": ("Side Effect 1", "slam", "front"),
    "twist_of_fate_2": ("Twist of Fate 2", "cutter", "front"),
    "middle_rope_twist_of_fate": ("Middle Rope Twist of Fate", "cutter", "corner"),
    "locomotion_northern_lights": ("Locomotion Northern Lights", "suplex", "front"),
    "superkick_3": ("Superkick 3", "kick", "front"),
    "wheelbarrow_facebuster": ("Wheelbarrow Facebuster", "slam", "front"),
    "superkick_1": ("Superkick 1", "kick", "front"),
    "game_over": ("Game Over", "submission", "ground"),
    "butterfly_shoulder_breaker": ("Butterfly Shoulder Breaker", "backbreaker", "front"),
    "heat_seeker": ("Heat Seeker", "driver", "front"),
    "salt_of_the_earth": ("Salt of the Earth", "submission", "ground"),
    "dynamite_diamond_ring_punch": ("Dynamite Diamond Ring Punch", "strike", "front"),
    "slingshot_destroyer": ("Slingshot Destroyer", "driver", "rope"),
    "superkick_5": ("Superkick 5", "kick", "front"),
    "splash_450_1": ("450 Splash 1", "aerial", "top_rope"),
    "draping_diving_knee_drop": ("Draping Diving Knee Drop", "aerial", "corner"),
    "orange_punch": ("Orange Punch", "strike", "front"),
    "beach_break": ("Beach Break", "driver", "front"),
    "diving_shooting_star": ("Diving Shooting Star", "aerial", "top_rope"),
    "black_arrow": ("Black Arrow", "aerial", "top_rope"),
    "penta_driver": ("Penta Driver", "driver", "front"),
    "package_piledriver_2": ("Package Piledriver 2", "piledriver", "front"),
    "oklahoma_stampede": ("Oklahoma Stampede", "slam", "running"),
    "running_step_up_tornillo_kick": ("Running Step-Up Tornillo Kick", "kick", "corner"),
    "fenix_driver_1": ("Fenix Driver 1", "driver", "front"),
    "fenix_driver_2": ("Fenix Driver 2", "driver", "front"),
    "rochambeau": ("Rochambeau", "driver", "front"),
    "diving_foot_stomp_1": ("Diving Foot Stomp 1", "aerial", "top_rope"),
    "victory_roll_foot_stomp": ("Victory Roll Foot Stomp", "combo", "front"),
    "gannosuke_clutch": ("Gannosuke Clutch", "pin", "front"),
    "corner_thrice_superkicks": ("Corner Thrice Superkicks", "kick", "corner"),
    "no_future": ("No Future", "kick", "kneeling"),
    "squatting_samoan_drop": ("Squatting Samoan Drop", "slam", "front"),
    "cody_cutter_5": ("Cody Cutter 5", "cutter", "front"),
    "splash_630": ("630 Splash", "aerial", "top_rope"),
    "pendulum_backbreaker_5": ("Pendulum Backbreaker 5", "backbreaker", "front"),
    "slingshot_cutter": ("Slingshot Cutter", "cutter", "rope"),
    "tko": ("TKO", "cutter", "front"),
    "heel_hook": ("Heel Hook", "submission", "ground"),
    "stinger_splash_2": ("Stinger Splash 2", "lariat", "corner"),
    "modified_lotus_lock": ("Modified Lotus Lock", "submission", "front"),
    "tay_ko": ("Tay-KO", "knee", "front"),
    "dd_tay": ("DD-Tay", "ddt", "front"),
    "running_lariat_slingshot_meteora_combo": ("Running Lariat/Slingshot Meteora Combo", "combo", "rope"),
    "sit_out_piledriver_1": ("Sit-Out Piledriver 1", "piledriver", "front"),
    "flying_single_leg_knee_strike_2": ("Flying Single Leg Knee Strike 2", "knee", "seated"),
    "strong_zero_1": ("Strong Zero 1", "driver", "front"),
    "basement_single_leg_knee_strike_2": ("Basement Single Leg Knee Strike 2", "knee", "seated"),
    "fireman_carry_buster": ("Fireman Carry Buster", "slam", "front"),
    "powerbomb_1": ("Powerbomb 1", "powerbomb", "front"),
    "casualty_of_war": ("Casualty of War", "lariat", "running"),
    "sleeper_hold": ("Sleeper Hold", "submission", "rear"),
    "magic_girl_splash_1": ("Magic Girl Splash 1", "aerial", "top_rope"),
    "crucifix_pin": ("Crucifix Pin", "pin", "front"),
    "hammerlock_airplane_spin": ("Hammerlock Airplane Spin", "slam", "front"),
    "half_moon_magic_girl_splash_1": ("Half-Moon Magic Girl Splash 1", "aerial", "top_rope"),
    "magic_girl_450_splash": ("Magic Girl 450 Splash", "aerial", "top_rope"),
}

# wrestler: (display name, signatures, specials) -- as the video shows them.
WRESTLERS = {
    "abadon": ("Abadon", [], ["cemetery_drive"]),
    "adam_cole": ("Adam Cole", ["snapmare_1", "shining_wizard", "ushigoroshi"],
                  ["the_boom", "panama_sunrise_2"]),
    "hangman_page": ("Hangman Adam Page", ["pop_up_powerbomb_1", "rope_fallaway_slam_moonsault"],
                     ["rope_fallaway_slam_moonsault", "dead_eye", "buckshot_lariat"]),
    "andrade": ("Andrade El Idolo", ["backbreaker_final_cut_combo", "jawbreaker", "brutalizer"],
                ["el_idolo_3"]),
    "anna_jay": ("Anna Jay", ["jay_kick_1"], ["queen_slayer"]),
    "brian_cage": ("Brian Cage", ["buckle_bomb", "weapon_x"], ["drill_claw", "avalanche_drill_claw"]),
    "britt_baker": ("Dr. Britt Baker D.M.D.", ["sling_blade_3", "fisherman_neckbreaker"],
                    ["lock_jaw_2", "strong_stomp_2"]),
    "bryan_danielson": ("Bryan Danielson", ["kick_combo", "diving_headbutt_1"],
                        ["lebell_lock_2", "cattle_mutilation", "flying_single_leg_knee_strike_1"]),
    "cash_wheeler": ("Cash Wheeler", [], ["spinebuster_5"]),
    "chris_jericho": ("Chris Jericho", ["code_breaker_1", "code_breaker_3", "springboard_moonsault_3"],
                      ["diving_judas_effect", "running_judas_effect", "judas_effect"]),
    "christian_cage": ("Christian Cage", ["diving_frog_splash", "inverted_ddt_1"],
                       ["inverted_ddt_1", "unprettier", "spear_2"]),
    "chuck_taylor": ("Chuck Taylor", ["sit_out_piledriver_6"], ["sole_food"]),
    "cm_punk": ("CM Punk", ["scoop_slam_2", "anaconda_vise"], ["gts_2"]),
    "cody_rhodes": ("Cody Rhodes", ["cody_cutter_4", "figure_four_leglock"],
                    ["tiger_driver_98", "cross_rhodes"]),
    "darby_allin": ("Darby Allin", ["code_red_2"], ["float_over_stunner", "coffin_drop_1", "neck_crank"]),
    "dax_harwood": ("Dax Harwood", ["sit_out_powerbomb_2"], ["brainbuster_1"]),
    "dustin_rhodes": ("Dustin Rhodes", ["code_red_1"], ["code_red_1", "final_reckoning"]),
    "eddie_kingston": ("Eddie Kingston", ["sleeper_suplex"], ["spinning_back_fist"]),
    "hikaru_shida": ("Hikaru Shida", ["falcon_arrow_3", "fireman_carry_backbreaker"],
                     ["snapmare_1", "katana", "tamashi_no"]),
    "jade_cargill": ("Jade Cargill", [], ["spinebuster_5", "jaded"]),
    "jeff_hardy": ("Jeff Hardy", [], ["gourdbuster_4", "twist_of_fate_1", "swanton_bomb"]),
    "john_silver": ("John Silver", ["the_meat_man_combo"], ["spin_doctor", "avalanche_torture_rack_bomb"]),
    "jon_moxley": ("Jon Moxley", ["gotch_style_piledriver"], ["arm_trapped_elbow_strikes", "bulldog_choke_2"]),
    "jungle_boy": ("Jungle Boy", ["avalanche_poison_rana"], ["poison_rana_1"]),
    "kenny_omega": ("Kenny Omega", ["running_v_trigger_3", "powerbomb_v_trigger_combo",
                                    "snap_dragon_suplex_3", "snap_dragon_suplex_2"],
                    ["running_v_trigger_1", "v_trigger_1", "one_winged_angel"]),
    "kris_statlander": ("Kris Statlander", [], ["electric_chair_facebuster_1"]),
    "lance_archer": ("Lance Archer", ["chokeslam_1", "old_school_moonsault"], ["black_out_1", "black_out_2"]),
    "luchasaurus": ("Luchasaurus", ["fireman_carry_bomb_2"], ["fireman_carry_bomb_2"]),
    "malakai_black": ("Malakai Black", ["brainbuster_1"], ["the_end"]),
    "matt_hardy": ("Matt Hardy", ["side_effect_1"], ["twist_of_fate_2", "middle_rope_twist_of_fate"]),
    "matt_jackson": ("Matt Jackson", ["locomotion_northern_lights"], ["superkick_3", "wheelbarrow_facebuster"]),
    "miro": ("Miro", ["superkick_1"], ["game_over"]),
    "mjf": ("MJF", ["butterfly_shoulder_breaker", "heat_seeker"],
            ["salt_of_the_earth", "dynamite_diamond_ring_punch"]),
    "nick_jackson": ("Nick Jackson", ["slingshot_destroyer"], ["superkick_5", "splash_450_1"]),
    "nyla_rose": ("Nyla Rose", ["draping_diving_knee_drop"], ["draping_diving_knee_drop"]),
    "orange_cassidy": ("Orange Cassidy", ["orange_punch"], ["orange_punch", "beach_break"]),
    "pac": ("PAC", ["sit_out_powerbomb_2", "diving_shooting_star"], ["black_arrow", "brutalizer"]),
    "penta": ("Penta El Zero M", ["penta_driver"], ["package_piledriver_2"]),
    "powerhouse_hobbs": ("Powerhouse Hobbs", [], ["spinebuster_5", "oklahoma_stampede"]),
    "aubrey_edwards": ("Aubrey Edwards", ["superkick_5"], ["superkick_5"]),
    "fenix": ("Rey Fenix", ["running_step_up_tornillo_kick"], ["fenix_driver_1", "fenix_driver_2"]),
    "ricky_starks": ("Ricky Starks", ["spear_2"], ["spear_2", "rochambeau"]),
    "riho": ("Riho", ["diving_foot_stomp_1", "victory_roll_foot_stomp"], ["gannosuke_clutch"]),
    "ruby_soho": ("Ruby Soho", ["corner_thrice_superkicks"], ["no_future"]),
    "sammy_guevara": ("Sammy Guevara", ["squatting_samoan_drop", "cody_cutter_5", "diving_shooting_star"],
                      ["cody_cutter_5", "splash_630"]),
    "scorpio_sky": ("Scorpio Sky", [], ["pendulum_backbreaker_5", "slingshot_cutter", "tko", "heel_hook"]),
    "sting": ("Sting", [], ["stinger_splash_2", "scoop_slam_2"]),
    "tay_conti": ("Tay Conti", [], ["modified_lotus_lock", "tay_ko", "dd_tay"]),
    "thunder_rosa": ("Thunder Rosa", [], ["running_lariat_slingshot_meteora_combo"]),
    "trent": ("Trent Beretta", [], ["sit_out_piledriver_1", "flying_single_leg_knee_strike_2",
                                    "strong_zero_1", "basement_single_leg_knee_strike_2"]),
    "wardlow": ("Wardlow", [], ["fireman_carry_buster", "powerbomb_1", "casualty_of_war"]),
    "yuka_sakazaki": ("Yuka Sakazaki", [], ["sleeper_hold", "magic_girl_splash_1", "crucifix_pin",
                                           "hammerlock_airplane_spin", "half_moon_magic_girl_splash_1",
                                           "magic_girl_450_splash"]),
}

# A move this project already animates: the library points at it instead of
# authoring a second copy.
EXISTING = {
    "cross_rhodes": "res://resources/moves/finisher_cross_rhodes.tres",
    "figure_four_leglock": "res://resources/moves/submission_figure_four.tres",
    # The springboard in off the middle rope, the head caught in the air --
    # Cody's dive spot's cutter ending (DiveSpot), which is FF's Cody Cutter 4.
    "cody_cutter_4": "res://resources/moves/dive_springboard_cutter.tres",
    # Batch 1 (19 Oct): the same moves as ones we already animate. FF's Spear
    # 2 is the running spear Roman finishes with; Cody Cutter 5 is the
    # standing cutter, Cody's own signature; Scoop Slam 2 is the body slam.
    "spear_2": "res://resources/moves/finisher_spear.tres",
    "cody_cutter_5": "res://resources/moves/signature_cody_cutter.tres",
    "scoop_slam_2": "res://resources/moves/power_bodyslam.tres",
    # Batch 2 (26 Oct): Roman's Samoan Drop is FF's squatting one -- he drops
    # to the crouch as the man falls off his shoulders.
    "squatting_samoan_drop": "res://resources/moves/power_samoan_drop.tres",
}

# The owner's ask (19 Oct): tag the library moves that suit our two men, built
# or not, so the batches know what to animate next. Keyed by OUR roster ids
# (Roman is not in Fight Forever). Cody's are his own FF set and the moves of
# his real ring style (the cutters, suplexes, the moonsault, the figure four);
# Roman's are a big man's power moves -- powerbombs, spinebuster, Samoan
# drops, the spear, the lariat.
FITS = {
    "cody": ["cody_cutter_4", "cody_cutter_5", "figure_four_leglock", "tiger_driver_98",
             "cross_rhodes", "scoop_slam_2", "brainbuster_1", "sit_out_powerbomb_2",
             "springboard_moonsault_3", "code_breaker_1", "inverted_ddt_1"],
    "roman": ["spear_2", "powerbomb_1", "sit_out_powerbomb_2", "spinebuster_5",
              "squatting_samoan_drop", "scoop_slam_2", "casualty_of_war",
              "fireman_carry_bomb_2", "buckle_bomb", "oklahoma_stampede"],
}

# Frame data by family, at 60 Hz: (startup, active, recovery). Paced to the
# measured Fight Forever tempo -- hoist to impact about 0.8 s on Cross Rhodes,
# the attacker up about a second after the landing (aew_ff_animation_review.md).
FAMILY_FRAMES = {
    "strike": (12, 4, 22), "kick": (14, 4, 24), "knee": (14, 4, 26), "lariat": (16, 4, 30),
    "spear": (18, 6, 32), "takedown": (24, 6, 30), "neckbreaker": (30, 6, 34),
    "cutter": (28, 6, 34), "ddt": (32, 6, 36), "stunner": (26, 6, 34), "slam": (40, 6, 36),
    "spinebuster": (34, 6, 34), "backbreaker": (36, 6, 34), "suplex": (44, 6, 36),
    "powerbomb": (48, 6, 38), "piledriver": (50, 6, 38), "driver": (48, 6, 38),
    "hurricanrana": (34, 6, 34), "aerial": (54, 6, 40), "combo": (60, 6, 40),
    "submission": (60, 0, 240), "pin": (36, 6, 30),
}
# Once a move is animated its frame data is its clip's: startup to the contact
# frame, recovery to the clip's end (frames at 60 Hz, clip frames at 30 fps x2).
CLIP_FRAMES = {
    "tiger_driver_98": (92, 6, 46),       # 72-frame clip at 30 fps: contact at 46
    "one_winged_angel": (80, 6, 46),      # 66 frames: contact at 40
    "powerbomb_1": (74, 6, 40),           # 60 frames: contact at 37
    "sit_out_powerbomb_2": (74, 6, 40),   # 60 frames: contact at 37
    "spinebuster_5": (52, 6, 50),         # 54 frames: contact at 26
    "brainbuster_1": (78, 6, 36),         # 60 frames: contact at 39
    "chokeslam_1": (68, 6, 34),           # 54 frames: contact at 34
    "oklahoma_stampede": (84, 6, 24),     # 57 frames: contact at 42
    "fireman_carry_bomb_2": (80, 6, 34),  # 60 frames: contact at 40
    "code_breaker_1": (28, 6, 38),        # 36 frames: contact at 14
    "inverted_ddt_1": (50, 6, 40),        # 48 frames: contact at 25
}

# Damage by tier: (head, torso, legs). A special is the big one.
TIER_DAMAGE = {"signature": (10.0, 8.0, 2.0), "special": (16.0, 12.0, 4.0)}
LEG_FAMILIES = {"submission"}


def tiers_of(move_id: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for w, (_name, sigs, specials) in WRESTLERS.items():
        for tier, ids in (("signature", sigs), ("special", specials)):
            if move_id in ids:
                out.setdefault(w, []).append(tier)
    return out


def tres(move_id: str) -> str:
    name, family, setup = MOVES[move_id]
    tiers = tiers_of(move_id)
    top = "special" if any("special" in t for t in tiers.values()) else "signature"
    su, ac, rc = CLIP_FRAMES.get(move_id, FAMILY_FRAMES[family])
    head, torso, legs = TIER_DAMAGE[top]
    if family in LEG_FAMILIES:
        head, legs = head * 0.4, legs + head * 0.6
    down = family not in ("strike", "kick", "submission", "pin") or top == "special"
    lines = [
        '[gd_resource type="Resource" script_class="MoveDef" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://resources/move_def.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        'resource_name = "%s"' % name.replace('"', '\\"'),
        'animation_pair_id = &"ff_%s"' % move_id,
        "startup_frames = %d" % su,
        "active_frames = %d" % ac,
        "recovery_frames = %d" % rc,
        "reversal_window_start = %d" % max(0, su - 10),
        "reversal_window_end = %d" % max(0, su - 2),
        "damage_head = %.1f" % head,
        "damage_torso = %.1f" % torso,
        "damage_arms = 0.0",
        "damage_legs = %.1f" % legs,
        "momentum_gain = %.1f" % (14.0 if top == "special" else 10.0),
        "leaves_defender_down = %s" % ("true" if down else "false"),
        'metadata/ff_name = "%s"' % name.replace('"', '\\"'),
        'metadata/ff_family = "%s"' % family,
        'metadata/ff_setup = "%s"' % setup,
        "metadata/ff_wrestlers = PackedStringArray(%s)" % ", ".join('"%s"' % w for w in sorted(tiers)),
        "",
    ]
    return "\n".join(lines)


def gd_dict(d: dict, indent: str = "\t") -> str:
    return "{\n" + "".join("%s%s,\n" % (indent, item) for item in d) + "}"


def library() -> str:
    w_items = []
    for w, (name, sigs, specials) in WRESTLERS.items():
        w_items.append('"%s": {"name": "%s", "signature": [%s], "special": [%s]}' % (
            w, name, ", ".join('"%s"' % s for s in sigs), ", ".join('"%s"' % s for s in specials)))
    m_items = []
    for m, (name, family, setup) in MOVES.items():
        m_items.append('"%s": {"name": "%s", "family": "%s", "setup": "%s", "wrestlers": [%s]}' % (
            m, name.replace('"', '\\"'), family, setup, ", ".join('"%s"' % w for w in sorted(tiers_of(m)))))
    ex_items = ['"%s": "%s"' % (k, v) for k, v in EXISTING.items()]
    fit_items = ['"%s": [%s]' % (k, ", ".join('"%s"' % m for m in v)) for k, v in FITS.items()]
    return "\n".join([
        "class_name FFMoveLibrary",
        "extends RefCounted",
        "## AEW Fight Forever's signatures and specials, every wrestler in the owner's",
        "## compilation, each move tagged to the wrestlers who use it",
        "## (gauntlet/refs/aew_ff_animation_review.md). GENERATED by",
        "## tools/moves/build_ff_library.py -- edit the table there, not here.",
        "##",
        "## A move is in the library before its animation is: is_built() says whether",
        "## its paired clip exists (or it reuses one of ours, EXISTING), and only a",
        "## built move may be given to a wrestler in a match.",
        "",
        'const DIR := "res://resources/moves/ff/"',
        'const PAIRED_LIBRARY := "res://resources/animations/paired_moves.tres"',
        "",
        "const WRESTLERS := " + gd_dict(w_items),
        "",
        "const MOVES := " + gd_dict(m_items),
        "",
        "## Moves we already animate under our own names.",
        "const EXISTING := " + gd_dict(ex_items),
        "",
        "## Library moves that suit our own men, built or not, by roster id: what",
        "## the batches animate first.",
        "const FITS := " + gd_dict(fit_items),
        "",
        "static var _paired: AnimationLibrary",
        "",
        "",
        "## The MoveDef for `move_id`: ours where we already have the move, else the",
        "## library's own.",
        "static func move(move_id: String) -> MoveDef:",
        "\tif EXISTING.has(move_id):",
        "\t\treturn load(EXISTING[move_id])",
        "\treturn load(DIR + move_id + \".tres\")",
        "",
        "",
        "## Every move of `wrestler`, signatures then specials, without repeats.",
        "static func moves_of(wrestler: String) -> Array[String]:",
        "\tvar out: Array[String] = []",
        "\tvar w: Dictionary = WRESTLERS.get(wrestler, {})",
        "\tfor tier: String in [\"signature\", \"special\"]:",
        "\t\tfor m: String in w.get(tier, []):",
        "\t\t\tif not out.has(m):",
        "\t\t\t\tout.append(m)",
        "\treturn out",
        "",
        "",
        "## The wrestlers a move belongs to.",
        "static func wrestlers_of(move_id: String) -> Array:",
        "\treturn (MOVES.get(move_id, {}) as Dictionary).get(\"wrestlers\", [])",
        "",
        "",
        "## Whether the move can be performed: its paired clip is authored, or it is",
        "## one of ours.",
        "static func is_built(move_id: String) -> bool:",
        "\tif EXISTING.has(move_id):",
        "\t\treturn true",
        "\tif _paired == null and ResourceLoader.exists(PAIRED_LIBRARY):",
        "\t\t_paired = load(PAIRED_LIBRARY)",
        "\treturn _paired != null and _paired.has_animation(StringName(\"ff_\" + move_id))",
        "",
        "",
        "## The library moves that suit one of our men (FITS), by roster id.",
        "static func fits_of(roster_id: String) -> Array:",
        "\treturn FITS.get(roster_id, [])",
        "",
        "",
        "## Built moves over all moves: how far the animation batches have got.",
        "static func progress() -> Vector2i:",
        "\tvar built := 0",
        "\tfor m: String in MOVES:",
        "\t\tif is_built(m):",
        "\t\t\tbuilt += 1",
        "\treturn Vector2i(built, MOVES.size())",
        "",
    ])


def main() -> int:
    # every referenced move is defined, every defined move is someone's
    used = {m for _n, s, x in WRESTLERS.values() for m in s + x}
    missing = used - MOVES.keys()
    orphan = MOVES.keys() - used
    assert not missing, "undefined moves: %s" % sorted(missing)
    assert not orphan, "moves nobody uses: %s" % sorted(orphan)
    unfit = {m for v in FITS.values() for m in v} - MOVES.keys()
    assert not unfit, "fits that are not library moves: %s" % sorted(unfit)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for m in MOVES:
        if m in EXISTING:
            continue
        (OUT_DIR / ("%s.tres" % m)).write_text(tres(m))
    LIB.write_text(library())
    print("ff library: %d wrestlers, %d moves (%d ours already)" % (
        len(WRESTLERS), len(MOVES), len(EXISTING)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
