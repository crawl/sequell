DROP TABLE IF EXISTS tmp_logrecord_tv;
CREATE TABLE tmp_logrecord_tv AS
SELECT gk.game_key, l.ntv
FROM logrecord AS l INNER JOIN l_game_key AS gk
  ON l.game_key_id = gk.id
WHERE ntv > 0;

DROP TABLE IF EXISTS tmp_milestone_tv;
CREATE TABLE tmp_milestone_tv AS
SELECT gk.game_key, l.rstart, l.ntv
FROM milestone AS l INNER JOIN l_game_key AS gk
  ON l.game_key_id = gk.id
WHERE ntv > 0;


DROP TABLE IF EXISTS tmp_spr_logrecord_tv;
CREATE TABLE tmp_spr_logrecord_tv AS
SELECT gk.game_key, ntv
FROM spr_logrecord AS l INNER JOIN l_game_key AS gk
  ON l.game_key_id = gk.id
WHERE ntv > 0;

DROP TABLE IF EXISTS tmp_spr_milestone_tv;
CREATE TABLE tmp_spr_milestone_tv AS
SELECT gk.game_key, l.rstart, l.ntv
FROM spr_milestone AS l INNER JOIN l_game_key AS gk
  ON l.game_key_id = gk.id
WHERE ntv > 0;

DROP TABLE IF EXISTS tmp_zot_logrecord_tv;
CREATE TABLE tmp_zot_logrecord_tv AS
SELECT gk.game_key, ntv
FROM zot_logrecord AS l INNER JOIN l_game_key AS gk
  ON l.game_key_id = gk.id
WHERE ntv > 0;

DROP TABLE IF EXISTS tmp_zot_milestone_tv;
CREATE TABLE tmp_zot_milestone_tv AS
SELECT gk.game_key, l.rstart, l.ntv
FROM zot_milestone AS l INNER JOIN l_game_key AS gk
  ON l.game_key_id = gk.id
WHERE ntv > 0;
