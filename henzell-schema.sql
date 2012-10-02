DROP TABLE IF EXISTS logrecord;
DROP TABLE IF EXISTS milestone;
DROP TABLE IF EXISTS spr_logrecord;
DROP TABLE IF EXISTS spr_milestone;
DROP TABLE IF EXISTS zot_logrecord;
DROP TABLE IF EXISTS zot_milestone;
DROP TABLE IF EXISTS l_br;
DROP TABLE IF EXISTS l_char;
DROP TABLE IF EXISTS l_cls;
DROP TABLE IF EXISTS l_crace;
DROP TABLE IF EXISTS l_file;
DROP TABLE IF EXISTS l_game_key;
DROP TABLE IF EXISTS l_god;
DROP TABLE IF EXISTS l_kaux;
DROP TABLE IF EXISTS l_killer;
DROP TABLE IF EXISTS l_kmod;
DROP TABLE IF EXISTS l_kpath;
DROP TABLE IF EXISTS l_ktyp;
DROP TABLE IF EXISTS l_ltyp;
DROP TABLE IF EXISTS l_lv;
DROP TABLE IF EXISTS l_map;
DROP TABLE IF EXISTS l_mapdesc;
DROP TABLE IF EXISTS l_milestone;
DROP TABLE IF EXISTS l_msg;
DROP TABLE IF EXISTS l_name;
DROP TABLE IF EXISTS l_noun;
DROP TABLE IF EXISTS l_oplace;
DROP TABLE IF EXISTS l_place;
DROP TABLE IF EXISTS l_race;
DROP TABLE IF EXISTS l_sk;
DROP TABLE IF EXISTS l_src;
DROP TABLE IF EXISTS l_title;
DROP TABLE IF EXISTS l_verb;
DROP TABLE IF EXISTS l_version;

CREATE TABLE l_br (
  id SERIAL,
  br CITEXT UNIQUE
)
;
CREATE TABLE l_char (
  id SERIAL,
  charabbrev CITEXT UNIQUE
)
;
CREATE TABLE l_cls (
  id SERIAL,
  cls CITEXT UNIQUE
)
;
CREATE TABLE l_crace (
  id SERIAL,
  crace CITEXT UNIQUE
)
;
CREATE TABLE l_file (
  id SERIAL,
  file CITEXT UNIQUE
)
;
CREATE TABLE l_game_key (
  id SERIAL,
  game_key CITEXT UNIQUE
)
;
CREATE TABLE l_god (
  id SERIAL,
  god CITEXT UNIQUE
)
;
CREATE TABLE l_kaux (
  id SERIAL,
  kaux CITEXT UNIQUE
)
;
CREATE TABLE l_killer (
  id SERIAL,
  killer CITEXT UNIQUE
)
;
CREATE TABLE l_kmod (
  id SERIAL,
  kmod CITEXT UNIQUE
)
;
CREATE TABLE l_kpath (
  id SERIAL,
  kpath CITEXT UNIQUE
)
;
CREATE TABLE l_ktyp (
  id SERIAL,
  ktyp CITEXT UNIQUE
)
;
CREATE TABLE l_ltyp (
  id SERIAL,
  ltyp CITEXT UNIQUE
)
;
CREATE TABLE l_lv (
  id SERIAL,
  lv CITEXT UNIQUE
)
;
CREATE TABLE l_map (
  id SERIAL,
  mapname CITEXT UNIQUE
)
;
CREATE TABLE l_mapdesc (
  id SERIAL,
  mapdesc CITEXT UNIQUE
)
;
CREATE TABLE l_milestone (
  id SERIAL,
  milestone CITEXT UNIQUE
)
;
CREATE TABLE l_msg (
  id SERIAL,
  tmsg CITEXT UNIQUE
)
;
CREATE TABLE l_name (
  id SERIAL,
  pname CITEXT UNIQUE
)
;
CREATE TABLE l_noun (
  id SERIAL,
  noun CITEXT UNIQUE
)
;
CREATE TABLE l_oplace (
  id SERIAL,
  oplace CITEXT UNIQUE
)
;
CREATE TABLE l_place (
  id SERIAL,
  place CITEXT UNIQUE
)
;
CREATE TABLE l_race (
  id SERIAL,
  race CITEXT UNIQUE
)
;
CREATE TABLE l_sk (
  id SERIAL,
  sk CITEXT UNIQUE
)
;
CREATE TABLE l_src (
  id SERIAL,
  src CITEXT UNIQUE
)
;
CREATE TABLE l_title (
  id SERIAL,
  title CITEXT UNIQUE
)
;
CREATE TABLE l_verb (
  id SERIAL,
  verb CITEXT UNIQUE
)
;
CREATE TABLE l_version (
  id SERIAL,
  v CITEXT UNIQUE
)
;
CREATE TABLE logrecord (
  id SERIAL,
  file_offset INT,
  game_key_id INT,
  file_id INT,
  alpha BOOLEAN,
  src_id INT,
  v_id INT,
  cv_id INT,
  lv_id INT,
  sc BIGINT,
  pname_id INT,
  race_id INT,
  crace_id INT,
  cls_id INT,
  charabbrev_id INT,
  xl INT,
  sk_id INT,
  sklev INT,
  title_id INT,
  ktyp_id INT,
  killer_id INT,
  ckiller_id INT,
  ikiller_id INT,
  kpath_id INT,
  kmod_id INT,
  kaux_id INT,
  ckaux_id INT,
  place_id INT,
  br_id INT,
  lvl INT,
  ltyp_id INT,
  hp INT,
  mhp INT,
  mmhp INT,
  dam INT,
  sstr INT,
  sint INT,
  sdex INT,
  god_id INT,
  piety INT,
  pen INT,
  wiz INT,
  tstart TIMESTAMP,
  tend TIMESTAMP,
  dur INT,
  turn INT,
  urune INT,
  nrune INT,
  tmsg_id INT,
  vmsg_id INT,
  splat BOOLEAN,
  rstart CITEXT,
  rend CITEXT,
  ntv INT,
  mapname_id INT,
  mapdesc_id INT,
  tiles BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (game_key_id) REFERENCES l_game_key (id),
  FOREIGN KEY (file_id) REFERENCES l_file (id),
  FOREIGN KEY (src_id) REFERENCES l_src (id),
  FOREIGN KEY (v_id) REFERENCES l_version (id),
  FOREIGN KEY (cv_id) REFERENCES l_version (id),
  FOREIGN KEY (lv_id) REFERENCES l_lv (id),
  FOREIGN KEY (pname_id) REFERENCES l_name (id),
  FOREIGN KEY (race_id) REFERENCES l_race (id),
  FOREIGN KEY (crace_id) REFERENCES l_crace (id),
  FOREIGN KEY (cls_id) REFERENCES l_cls (id),
  FOREIGN KEY (charabbrev_id) REFERENCES l_char (id),
  FOREIGN KEY (sk_id) REFERENCES l_sk (id),
  FOREIGN KEY (title_id) REFERENCES l_title (id),
  FOREIGN KEY (ktyp_id) REFERENCES l_ktyp (id),
  FOREIGN KEY (killer_id) REFERENCES l_killer (id),
  FOREIGN KEY (ckiller_id) REFERENCES l_killer (id),
  FOREIGN KEY (ikiller_id) REFERENCES l_killer (id),
  FOREIGN KEY (kpath_id) REFERENCES l_kpath (id),
  FOREIGN KEY (kmod_id) REFERENCES l_kmod (id),
  FOREIGN KEY (kaux_id) REFERENCES l_kaux (id),
  FOREIGN KEY (ckaux_id) REFERENCES l_kaux (id),
  FOREIGN KEY (place_id) REFERENCES l_place (id),
  FOREIGN KEY (br_id) REFERENCES l_br (id),
  FOREIGN KEY (ltyp_id) REFERENCES l_ltyp (id),
  FOREIGN KEY (god_id) REFERENCES l_god (id),
  FOREIGN KEY (tmsg_id) REFERENCES l_msg (id),
  FOREIGN KEY (vmsg_id) REFERENCES l_msg (id),
  FOREIGN KEY (mapname_id) REFERENCES l_map (id),
  FOREIGN KEY (mapdesc_id) REFERENCES l_mapdesc (id)
)
;
CREATE INDEX ind_logrecord_file_file_offset ON logrecord (file, file_offset);
CREATE INDEX ind_logrecord_file_offset ON logrecord (file_offset);
CREATE INDEX ind_logrecord_game_key ON logrecord (game_key);
CREATE INDEX ind_logrecord_file ON logrecord (file);
CREATE INDEX ind_logrecord_src ON logrecord (src);
CREATE INDEX ind_logrecord_v ON logrecord (v);
CREATE INDEX ind_logrecord_cv ON logrecord (cv);
CREATE INDEX ind_logrecord_sc ON logrecord (sc);
CREATE INDEX ind_logrecord_pname ON logrecord (pname);
CREATE INDEX ind_logrecord_race ON logrecord (race);
CREATE INDEX ind_logrecord_crace ON logrecord (crace);
CREATE INDEX ind_logrecord_cls ON logrecord (cls);
CREATE INDEX ind_logrecord_charabbrev ON logrecord (charabbrev);
CREATE INDEX ind_logrecord_xl ON logrecord (xl);
CREATE INDEX ind_logrecord_sk ON logrecord (sk);
CREATE INDEX ind_logrecord_sklev ON logrecord (sklev);
CREATE INDEX ind_logrecord_title ON logrecord (title);
CREATE INDEX ind_logrecord_ktyp ON logrecord (ktyp);
CREATE INDEX ind_logrecord_killer ON logrecord (killer);
CREATE INDEX ind_logrecord_ckiller ON logrecord (ckiller);
CREATE INDEX ind_logrecord_ikiller ON logrecord (ikiller);
CREATE INDEX ind_logrecord_kaux ON logrecord (kaux);
CREATE INDEX ind_logrecord_ckaux ON logrecord (ckaux);
CREATE INDEX ind_logrecord_place ON logrecord (place);
CREATE INDEX ind_logrecord_god ON logrecord (god);
CREATE INDEX ind_logrecord_tstart ON logrecord (tstart);
CREATE INDEX ind_logrecord_tend ON logrecord (tend);
CREATE INDEX ind_logrecord_dur ON logrecord (dur);
CREATE INDEX ind_logrecord_turn ON logrecord (turn);
CREATE INDEX ind_logrecord_urune ON logrecord (urune);
CREATE INDEX ind_logrecord_nrune ON logrecord (nrune);
CREATE INDEX ind_logrecord_rstart ON logrecord (rstart);
CREATE INDEX ind_logrecord_rend ON logrecord (rend);
CREATE INDEX ind_logrecord_ntv ON logrecord (ntv);
CREATE INDEX ind_logrecord_mapname ON logrecord (mapname);
CREATE TABLE milestone (
  id SERIAL,
  game_key_id INT,
  file_offset INT,
  file_id INT,
  alpha BOOLEAN,
  src_id INT,
  v_id INT,
  cv_id INT,
  pname_id INT,
  race_id INT,
  crace_id INT,
  cls_id INT,
  charabbrev_id INT,
  xl INT,
  sk_id INT,
  sklev INT,
  title_id INT,
  place_id INT,
  br_id INT,
  lvl INT,
  ltyp_id INT,
  hp INT,
  mhp INT,
  mmhp INT,
  sstr INT,
  sint INT,
  sdex INT,
  god_id INT,
  dur INT,
  turn INT,
  urune INT,
  nrune INT,
  ttime TIMESTAMP,
  rtime CITEXT,
  rstart CITEXT,
  verb_id INT,
  noun_id INT,
  milestone_id INT,
  ntv INT,
  oplace_id INT,
  tiles BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (game_key_id) REFERENCES l_game_key (id),
  FOREIGN KEY (file_id) REFERENCES l_file (id),
  FOREIGN KEY (src_id) REFERENCES l_src (id),
  FOREIGN KEY (v_id) REFERENCES l_version (id),
  FOREIGN KEY (cv_id) REFERENCES l_version (id),
  FOREIGN KEY (pname_id) REFERENCES l_name (id),
  FOREIGN KEY (race_id) REFERENCES l_race (id),
  FOREIGN KEY (crace_id) REFERENCES l_crace (id),
  FOREIGN KEY (cls_id) REFERENCES l_cls (id),
  FOREIGN KEY (charabbrev_id) REFERENCES l_char (id),
  FOREIGN KEY (sk_id) REFERENCES l_sk (id),
  FOREIGN KEY (title_id) REFERENCES l_title (id),
  FOREIGN KEY (place_id) REFERENCES l_place (id),
  FOREIGN KEY (br_id) REFERENCES l_br (id),
  FOREIGN KEY (ltyp_id) REFERENCES l_ltyp (id),
  FOREIGN KEY (god_id) REFERENCES l_god (id),
  FOREIGN KEY (verb_id) REFERENCES l_verb (id),
  FOREIGN KEY (noun_id) REFERENCES l_noun (id),
  FOREIGN KEY (milestone_id) REFERENCES l_milestone (id),
  FOREIGN KEY (oplace_id) REFERENCES l_oplace (id)
)
;
CREATE INDEX ind_milestone_file_file_offset ON milestone (file, file_offset);
CREATE INDEX ind_milestone_verb_noun ON milestone (verb, noun);
CREATE INDEX ind_milestone_game_key ON milestone (game_key);
CREATE INDEX ind_milestone_file_offset ON milestone (file_offset);
CREATE INDEX ind_milestone_file ON milestone (file);
CREATE INDEX ind_milestone_src ON milestone (src);
CREATE INDEX ind_milestone_v ON milestone (v);
CREATE INDEX ind_milestone_cv ON milestone (cv);
CREATE INDEX ind_milestone_pname ON milestone (pname);
CREATE INDEX ind_milestone_race ON milestone (race);
CREATE INDEX ind_milestone_crace ON milestone (crace);
CREATE INDEX ind_milestone_cls ON milestone (cls);
CREATE INDEX ind_milestone_charabbrev ON milestone (charabbrev);
CREATE INDEX ind_milestone_xl ON milestone (xl);
CREATE INDEX ind_milestone_sk ON milestone (sk);
CREATE INDEX ind_milestone_sklev ON milestone (sklev);
CREATE INDEX ind_milestone_title ON milestone (title);
CREATE INDEX ind_milestone_place ON milestone (place);
CREATE INDEX ind_milestone_god ON milestone (god);
CREATE INDEX ind_milestone_turn ON milestone (turn);
CREATE INDEX ind_milestone_urune ON milestone (urune);
CREATE INDEX ind_milestone_nrune ON milestone (nrune);
CREATE INDEX ind_milestone_ttime ON milestone (ttime);
CREATE INDEX ind_milestone_rtime ON milestone (rtime);
CREATE INDEX ind_milestone_rstart ON milestone (rstart);
CREATE INDEX ind_milestone_verb ON milestone (verb);
CREATE INDEX ind_milestone_noun ON milestone (noun);
CREATE INDEX ind_milestone_ntv ON milestone (ntv);
CREATE TABLE spr_logrecord (
  id SERIAL,
  file_offset INT,
  game_key_id INT,
  file_id INT,
  alpha BOOLEAN,
  src_id INT,
  v_id INT,
  cv_id INT,
  lv_id INT,
  sc BIGINT,
  pname_id INT,
  race_id INT,
  crace_id INT,
  cls_id INT,
  charabbrev_id INT,
  xl INT,
  sk_id INT,
  sklev INT,
  title_id INT,
  ktyp_id INT,
  killer_id INT,
  ckiller_id INT,
  ikiller_id INT,
  kpath_id INT,
  kmod_id INT,
  kaux_id INT,
  ckaux_id INT,
  place_id INT,
  br_id INT,
  lvl INT,
  ltyp_id INT,
  hp INT,
  mhp INT,
  mmhp INT,
  dam INT,
  sstr INT,
  sint INT,
  sdex INT,
  god_id INT,
  piety INT,
  pen INT,
  wiz INT,
  tstart TIMESTAMP,
  tend TIMESTAMP,
  dur INT,
  turn INT,
  urune INT,
  nrune INT,
  tmsg_id INT,
  vmsg_id INT,
  splat BOOLEAN,
  rstart CITEXT,
  rend CITEXT,
  ntv INT,
  mapname_id INT,
  mapdesc_id INT,
  tiles BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (game_key_id) REFERENCES l_game_key (id),
  FOREIGN KEY (file_id) REFERENCES l_file (id),
  FOREIGN KEY (src_id) REFERENCES l_src (id),
  FOREIGN KEY (v_id) REFERENCES l_version (id),
  FOREIGN KEY (cv_id) REFERENCES l_version (id),
  FOREIGN KEY (lv_id) REFERENCES l_lv (id),
  FOREIGN KEY (pname_id) REFERENCES l_name (id),
  FOREIGN KEY (race_id) REFERENCES l_race (id),
  FOREIGN KEY (crace_id) REFERENCES l_crace (id),
  FOREIGN KEY (cls_id) REFERENCES l_cls (id),
  FOREIGN KEY (charabbrev_id) REFERENCES l_char (id),
  FOREIGN KEY (sk_id) REFERENCES l_sk (id),
  FOREIGN KEY (title_id) REFERENCES l_title (id),
  FOREIGN KEY (ktyp_id) REFERENCES l_ktyp (id),
  FOREIGN KEY (killer_id) REFERENCES l_killer (id),
  FOREIGN KEY (ckiller_id) REFERENCES l_killer (id),
  FOREIGN KEY (ikiller_id) REFERENCES l_killer (id),
  FOREIGN KEY (kpath_id) REFERENCES l_kpath (id),
  FOREIGN KEY (kmod_id) REFERENCES l_kmod (id),
  FOREIGN KEY (kaux_id) REFERENCES l_kaux (id),
  FOREIGN KEY (ckaux_id) REFERENCES l_kaux (id),
  FOREIGN KEY (place_id) REFERENCES l_place (id),
  FOREIGN KEY (br_id) REFERENCES l_br (id),
  FOREIGN KEY (ltyp_id) REFERENCES l_ltyp (id),
  FOREIGN KEY (god_id) REFERENCES l_god (id),
  FOREIGN KEY (tmsg_id) REFERENCES l_msg (id),
  FOREIGN KEY (vmsg_id) REFERENCES l_msg (id),
  FOREIGN KEY (mapname_id) REFERENCES l_map (id),
  FOREIGN KEY (mapdesc_id) REFERENCES l_mapdesc (id)
)
;
CREATE INDEX ind_spr_logrecord_file_file_offset ON spr_logrecord (file, file_offset);
CREATE INDEX ind_spr_logrecord_file_offset ON spr_logrecord (file_offset);
CREATE INDEX ind_spr_logrecord_game_key ON spr_logrecord (game_key);
CREATE INDEX ind_spr_logrecord_file ON spr_logrecord (file);
CREATE INDEX ind_spr_logrecord_src ON spr_logrecord (src);
CREATE INDEX ind_spr_logrecord_v ON spr_logrecord (v);
CREATE INDEX ind_spr_logrecord_cv ON spr_logrecord (cv);
CREATE INDEX ind_spr_logrecord_sc ON spr_logrecord (sc);
CREATE INDEX ind_spr_logrecord_pname ON spr_logrecord (pname);
CREATE INDEX ind_spr_logrecord_race ON spr_logrecord (race);
CREATE INDEX ind_spr_logrecord_crace ON spr_logrecord (crace);
CREATE INDEX ind_spr_logrecord_cls ON spr_logrecord (cls);
CREATE INDEX ind_spr_logrecord_charabbrev ON spr_logrecord (charabbrev);
CREATE INDEX ind_spr_logrecord_xl ON spr_logrecord (xl);
CREATE INDEX ind_spr_logrecord_sk ON spr_logrecord (sk);
CREATE INDEX ind_spr_logrecord_sklev ON spr_logrecord (sklev);
CREATE INDEX ind_spr_logrecord_title ON spr_logrecord (title);
CREATE INDEX ind_spr_logrecord_ktyp ON spr_logrecord (ktyp);
CREATE INDEX ind_spr_logrecord_killer ON spr_logrecord (killer);
CREATE INDEX ind_spr_logrecord_ckiller ON spr_logrecord (ckiller);
CREATE INDEX ind_spr_logrecord_ikiller ON spr_logrecord (ikiller);
CREATE INDEX ind_spr_logrecord_kaux ON spr_logrecord (kaux);
CREATE INDEX ind_spr_logrecord_ckaux ON spr_logrecord (ckaux);
CREATE INDEX ind_spr_logrecord_place ON spr_logrecord (place);
CREATE INDEX ind_spr_logrecord_god ON spr_logrecord (god);
CREATE INDEX ind_spr_logrecord_tstart ON spr_logrecord (tstart);
CREATE INDEX ind_spr_logrecord_tend ON spr_logrecord (tend);
CREATE INDEX ind_spr_logrecord_dur ON spr_logrecord (dur);
CREATE INDEX ind_spr_logrecord_turn ON spr_logrecord (turn);
CREATE INDEX ind_spr_logrecord_urune ON spr_logrecord (urune);
CREATE INDEX ind_spr_logrecord_nrune ON spr_logrecord (nrune);
CREATE INDEX ind_spr_logrecord_rstart ON spr_logrecord (rstart);
CREATE INDEX ind_spr_logrecord_rend ON spr_logrecord (rend);
CREATE INDEX ind_spr_logrecord_ntv ON spr_logrecord (ntv);
CREATE INDEX ind_spr_logrecord_mapname ON spr_logrecord (mapname);
CREATE TABLE spr_milestone (
  id SERIAL,
  game_key_id INT,
  file_offset INT,
  file_id INT,
  alpha BOOLEAN,
  src_id INT,
  v_id INT,
  cv_id INT,
  pname_id INT,
  race_id INT,
  crace_id INT,
  cls_id INT,
  charabbrev_id INT,
  xl INT,
  sk_id INT,
  sklev INT,
  title_id INT,
  place_id INT,
  br_id INT,
  lvl INT,
  ltyp_id INT,
  hp INT,
  mhp INT,
  mmhp INT,
  sstr INT,
  sint INT,
  sdex INT,
  god_id INT,
  dur INT,
  turn INT,
  urune INT,
  nrune INT,
  ttime TIMESTAMP,
  rtime CITEXT,
  rstart CITEXT,
  verb_id INT,
  noun_id INT,
  milestone_id INT,
  ntv INT,
  oplace_id INT,
  tiles BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (game_key_id) REFERENCES l_game_key (id),
  FOREIGN KEY (file_id) REFERENCES l_file (id),
  FOREIGN KEY (src_id) REFERENCES l_src (id),
  FOREIGN KEY (v_id) REFERENCES l_version (id),
  FOREIGN KEY (cv_id) REFERENCES l_version (id),
  FOREIGN KEY (pname_id) REFERENCES l_name (id),
  FOREIGN KEY (race_id) REFERENCES l_race (id),
  FOREIGN KEY (crace_id) REFERENCES l_crace (id),
  FOREIGN KEY (cls_id) REFERENCES l_cls (id),
  FOREIGN KEY (charabbrev_id) REFERENCES l_char (id),
  FOREIGN KEY (sk_id) REFERENCES l_sk (id),
  FOREIGN KEY (title_id) REFERENCES l_title (id),
  FOREIGN KEY (place_id) REFERENCES l_place (id),
  FOREIGN KEY (br_id) REFERENCES l_br (id),
  FOREIGN KEY (ltyp_id) REFERENCES l_ltyp (id),
  FOREIGN KEY (god_id) REFERENCES l_god (id),
  FOREIGN KEY (verb_id) REFERENCES l_verb (id),
  FOREIGN KEY (noun_id) REFERENCES l_noun (id),
  FOREIGN KEY (milestone_id) REFERENCES l_milestone (id),
  FOREIGN KEY (oplace_id) REFERENCES l_oplace (id)
)
;
CREATE INDEX ind_spr_milestone_file_file_offset ON spr_milestone (file, file_offset);
CREATE INDEX ind_spr_milestone_verb_noun ON spr_milestone (verb, noun);
CREATE INDEX ind_spr_milestone_game_key ON spr_milestone (game_key);
CREATE INDEX ind_spr_milestone_file_offset ON spr_milestone (file_offset);
CREATE INDEX ind_spr_milestone_file ON spr_milestone (file);
CREATE INDEX ind_spr_milestone_src ON spr_milestone (src);
CREATE INDEX ind_spr_milestone_v ON spr_milestone (v);
CREATE INDEX ind_spr_milestone_cv ON spr_milestone (cv);
CREATE INDEX ind_spr_milestone_pname ON spr_milestone (pname);
CREATE INDEX ind_spr_milestone_race ON spr_milestone (race);
CREATE INDEX ind_spr_milestone_crace ON spr_milestone (crace);
CREATE INDEX ind_spr_milestone_cls ON spr_milestone (cls);
CREATE INDEX ind_spr_milestone_charabbrev ON spr_milestone (charabbrev);
CREATE INDEX ind_spr_milestone_xl ON spr_milestone (xl);
CREATE INDEX ind_spr_milestone_sk ON spr_milestone (sk);
CREATE INDEX ind_spr_milestone_sklev ON spr_milestone (sklev);
CREATE INDEX ind_spr_milestone_title ON spr_milestone (title);
CREATE INDEX ind_spr_milestone_place ON spr_milestone (place);
CREATE INDEX ind_spr_milestone_god ON spr_milestone (god);
CREATE INDEX ind_spr_milestone_turn ON spr_milestone (turn);
CREATE INDEX ind_spr_milestone_urune ON spr_milestone (urune);
CREATE INDEX ind_spr_milestone_nrune ON spr_milestone (nrune);
CREATE INDEX ind_spr_milestone_ttime ON spr_milestone (ttime);
CREATE INDEX ind_spr_milestone_rtime ON spr_milestone (rtime);
CREATE INDEX ind_spr_milestone_rstart ON spr_milestone (rstart);
CREATE INDEX ind_spr_milestone_verb ON spr_milestone (verb);
CREATE INDEX ind_spr_milestone_noun ON spr_milestone (noun);
CREATE INDEX ind_spr_milestone_ntv ON spr_milestone (ntv);
CREATE TABLE zot_logrecord (
  id SERIAL,
  file_offset INT,
  game_key_id INT,
  file_id INT,
  alpha BOOLEAN,
  src_id INT,
  v_id INT,
  cv_id INT,
  lv_id INT,
  sc BIGINT,
  pname_id INT,
  race_id INT,
  crace_id INT,
  cls_id INT,
  charabbrev_id INT,
  xl INT,
  sk_id INT,
  sklev INT,
  title_id INT,
  ktyp_id INT,
  killer_id INT,
  ckiller_id INT,
  ikiller_id INT,
  kpath_id INT,
  kmod_id INT,
  kaux_id INT,
  ckaux_id INT,
  place_id INT,
  br_id INT,
  lvl INT,
  ltyp_id INT,
  hp INT,
  mhp INT,
  mmhp INT,
  dam INT,
  sstr INT,
  sint INT,
  sdex INT,
  god_id INT,
  piety INT,
  pen INT,
  wiz INT,
  tstart TIMESTAMP,
  tend TIMESTAMP,
  dur INT,
  turn INT,
  urune INT,
  nrune INT,
  tmsg_id INT,
  vmsg_id INT,
  splat BOOLEAN,
  rstart CITEXT,
  rend CITEXT,
  ntv INT,
  mapname_id INT,
  mapdesc_id INT,
  tiles BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (game_key_id) REFERENCES l_game_key (id),
  FOREIGN KEY (file_id) REFERENCES l_file (id),
  FOREIGN KEY (src_id) REFERENCES l_src (id),
  FOREIGN KEY (v_id) REFERENCES l_version (id),
  FOREIGN KEY (cv_id) REFERENCES l_version (id),
  FOREIGN KEY (lv_id) REFERENCES l_lv (id),
  FOREIGN KEY (pname_id) REFERENCES l_name (id),
  FOREIGN KEY (race_id) REFERENCES l_race (id),
  FOREIGN KEY (crace_id) REFERENCES l_crace (id),
  FOREIGN KEY (cls_id) REFERENCES l_cls (id),
  FOREIGN KEY (charabbrev_id) REFERENCES l_char (id),
  FOREIGN KEY (sk_id) REFERENCES l_sk (id),
  FOREIGN KEY (title_id) REFERENCES l_title (id),
  FOREIGN KEY (ktyp_id) REFERENCES l_ktyp (id),
  FOREIGN KEY (killer_id) REFERENCES l_killer (id),
  FOREIGN KEY (ckiller_id) REFERENCES l_killer (id),
  FOREIGN KEY (ikiller_id) REFERENCES l_killer (id),
  FOREIGN KEY (kpath_id) REFERENCES l_kpath (id),
  FOREIGN KEY (kmod_id) REFERENCES l_kmod (id),
  FOREIGN KEY (kaux_id) REFERENCES l_kaux (id),
  FOREIGN KEY (ckaux_id) REFERENCES l_kaux (id),
  FOREIGN KEY (place_id) REFERENCES l_place (id),
  FOREIGN KEY (br_id) REFERENCES l_br (id),
  FOREIGN KEY (ltyp_id) REFERENCES l_ltyp (id),
  FOREIGN KEY (god_id) REFERENCES l_god (id),
  FOREIGN KEY (tmsg_id) REFERENCES l_msg (id),
  FOREIGN KEY (vmsg_id) REFERENCES l_msg (id),
  FOREIGN KEY (mapname_id) REFERENCES l_map (id),
  FOREIGN KEY (mapdesc_id) REFERENCES l_mapdesc (id)
)
;
CREATE INDEX ind_zot_logrecord_file_file_offset ON zot_logrecord (file, file_offset);
CREATE INDEX ind_zot_logrecord_file_offset ON zot_logrecord (file_offset);
CREATE INDEX ind_zot_logrecord_game_key ON zot_logrecord (game_key);
CREATE INDEX ind_zot_logrecord_file ON zot_logrecord (file);
CREATE INDEX ind_zot_logrecord_src ON zot_logrecord (src);
CREATE INDEX ind_zot_logrecord_v ON zot_logrecord (v);
CREATE INDEX ind_zot_logrecord_cv ON zot_logrecord (cv);
CREATE INDEX ind_zot_logrecord_sc ON zot_logrecord (sc);
CREATE INDEX ind_zot_logrecord_pname ON zot_logrecord (pname);
CREATE INDEX ind_zot_logrecord_race ON zot_logrecord (race);
CREATE INDEX ind_zot_logrecord_crace ON zot_logrecord (crace);
CREATE INDEX ind_zot_logrecord_cls ON zot_logrecord (cls);
CREATE INDEX ind_zot_logrecord_charabbrev ON zot_logrecord (charabbrev);
CREATE INDEX ind_zot_logrecord_xl ON zot_logrecord (xl);
CREATE INDEX ind_zot_logrecord_sk ON zot_logrecord (sk);
CREATE INDEX ind_zot_logrecord_sklev ON zot_logrecord (sklev);
CREATE INDEX ind_zot_logrecord_title ON zot_logrecord (title);
CREATE INDEX ind_zot_logrecord_ktyp ON zot_logrecord (ktyp);
CREATE INDEX ind_zot_logrecord_killer ON zot_logrecord (killer);
CREATE INDEX ind_zot_logrecord_ckiller ON zot_logrecord (ckiller);
CREATE INDEX ind_zot_logrecord_ikiller ON zot_logrecord (ikiller);
CREATE INDEX ind_zot_logrecord_kaux ON zot_logrecord (kaux);
CREATE INDEX ind_zot_logrecord_ckaux ON zot_logrecord (ckaux);
CREATE INDEX ind_zot_logrecord_place ON zot_logrecord (place);
CREATE INDEX ind_zot_logrecord_god ON zot_logrecord (god);
CREATE INDEX ind_zot_logrecord_tstart ON zot_logrecord (tstart);
CREATE INDEX ind_zot_logrecord_tend ON zot_logrecord (tend);
CREATE INDEX ind_zot_logrecord_dur ON zot_logrecord (dur);
CREATE INDEX ind_zot_logrecord_turn ON zot_logrecord (turn);
CREATE INDEX ind_zot_logrecord_urune ON zot_logrecord (urune);
CREATE INDEX ind_zot_logrecord_nrune ON zot_logrecord (nrune);
CREATE INDEX ind_zot_logrecord_rstart ON zot_logrecord (rstart);
CREATE INDEX ind_zot_logrecord_rend ON zot_logrecord (rend);
CREATE INDEX ind_zot_logrecord_ntv ON zot_logrecord (ntv);
CREATE INDEX ind_zot_logrecord_mapname ON zot_logrecord (mapname);
CREATE TABLE zot_milestone (
  id SERIAL,
  game_key_id INT,
  file_offset INT,
  file_id INT,
  alpha BOOLEAN,
  src_id INT,
  v_id INT,
  cv_id INT,
  pname_id INT,
  race_id INT,
  crace_id INT,
  cls_id INT,
  charabbrev_id INT,
  xl INT,
  sk_id INT,
  sklev INT,
  title_id INT,
  place_id INT,
  br_id INT,
  lvl INT,
  ltyp_id INT,
  hp INT,
  mhp INT,
  mmhp INT,
  sstr INT,
  sint INT,
  sdex INT,
  god_id INT,
  dur INT,
  turn INT,
  urune INT,
  nrune INT,
  ttime TIMESTAMP,
  rtime CITEXT,
  rstart CITEXT,
  verb_id INT,
  noun_id INT,
  milestone_id INT,
  ntv INT,
  oplace_id INT,
  tiles BOOLEAN,
  PRIMARY KEY (id),
  FOREIGN KEY (game_key_id) REFERENCES l_game_key (id),
  FOREIGN KEY (file_id) REFERENCES l_file (id),
  FOREIGN KEY (src_id) REFERENCES l_src (id),
  FOREIGN KEY (v_id) REFERENCES l_version (id),
  FOREIGN KEY (cv_id) REFERENCES l_version (id),
  FOREIGN KEY (pname_id) REFERENCES l_name (id),
  FOREIGN KEY (race_id) REFERENCES l_race (id),
  FOREIGN KEY (crace_id) REFERENCES l_crace (id),
  FOREIGN KEY (cls_id) REFERENCES l_cls (id),
  FOREIGN KEY (charabbrev_id) REFERENCES l_char (id),
  FOREIGN KEY (sk_id) REFERENCES l_sk (id),
  FOREIGN KEY (title_id) REFERENCES l_title (id),
  FOREIGN KEY (place_id) REFERENCES l_place (id),
  FOREIGN KEY (br_id) REFERENCES l_br (id),
  FOREIGN KEY (ltyp_id) REFERENCES l_ltyp (id),
  FOREIGN KEY (god_id) REFERENCES l_god (id),
  FOREIGN KEY (verb_id) REFERENCES l_verb (id),
  FOREIGN KEY (noun_id) REFERENCES l_noun (id),
  FOREIGN KEY (milestone_id) REFERENCES l_milestone (id),
  FOREIGN KEY (oplace_id) REFERENCES l_oplace (id)
)
;
CREATE INDEX ind_zot_milestone_file_file_offset ON zot_milestone (file, file_offset);
CREATE INDEX ind_zot_milestone_verb_noun ON zot_milestone (verb, noun);
CREATE INDEX ind_zot_milestone_game_key ON zot_milestone (game_key);
CREATE INDEX ind_zot_milestone_file_offset ON zot_milestone (file_offset);
CREATE INDEX ind_zot_milestone_file ON zot_milestone (file);
CREATE INDEX ind_zot_milestone_src ON zot_milestone (src);
CREATE INDEX ind_zot_milestone_v ON zot_milestone (v);
CREATE INDEX ind_zot_milestone_cv ON zot_milestone (cv);
CREATE INDEX ind_zot_milestone_pname ON zot_milestone (pname);
CREATE INDEX ind_zot_milestone_race ON zot_milestone (race);
CREATE INDEX ind_zot_milestone_crace ON zot_milestone (crace);
CREATE INDEX ind_zot_milestone_cls ON zot_milestone (cls);
CREATE INDEX ind_zot_milestone_charabbrev ON zot_milestone (charabbrev);
CREATE INDEX ind_zot_milestone_xl ON zot_milestone (xl);
CREATE INDEX ind_zot_milestone_sk ON zot_milestone (sk);
CREATE INDEX ind_zot_milestone_sklev ON zot_milestone (sklev);
CREATE INDEX ind_zot_milestone_title ON zot_milestone (title);
CREATE INDEX ind_zot_milestone_place ON zot_milestone (place);
CREATE INDEX ind_zot_milestone_god ON zot_milestone (god);
CREATE INDEX ind_zot_milestone_turn ON zot_milestone (turn);
CREATE INDEX ind_zot_milestone_urune ON zot_milestone (urune);
CREATE INDEX ind_zot_milestone_nrune ON zot_milestone (nrune);
CREATE INDEX ind_zot_milestone_ttime ON zot_milestone (ttime);
CREATE INDEX ind_zot_milestone_rtime ON zot_milestone (rtime);
CREATE INDEX ind_zot_milestone_rstart ON zot_milestone (rstart);
CREATE INDEX ind_zot_milestone_verb ON zot_milestone (verb);
CREATE INDEX ind_zot_milestone_noun ON zot_milestone (noun);
CREATE INDEX ind_zot_milestone_ntv ON zot_milestone (ntv);;
