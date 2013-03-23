UPDATE logrecord AS l
   SET ntv = tv.ntv
  FROM tmp_logrecord_tv AS tv
INNER JOIN l_game_key AS gk ON tv.game_key = gk.game_key
 WHERE l.game_key_id = gk.id;
 
UPDATE milestone AS l
   SET ntv = tv.ntv
  FROM tmp_milestone_tv AS tv
INNER JOIN l_game_key AS gk ON tv.game_key = gk.game_key
 WHERE l.game_key_id = gk.id
   AND tv.rstart = l.rstart;
 

UPDATE spr_logrecord AS l
   SET ntv = tv.ntv
  FROM tmp_spr_logrecord_tv AS tv
INNER JOIN l_game_key AS gk ON tv.game_key = gk.game_key
 WHERE l.game_key_id = gk.id;
 
UPDATE spr_milestone AS l
   SET ntv = tv.ntv
  FROM tmp_spr_milestone_tv AS tv
INNER JOIN l_game_key AS gk ON tv.game_key = gk.game_key
 WHERE l.game_key_id = gk.id
   AND tv.rstart = l.rstart;
 

UPDATE zot_logrecord AS l
   SET ntv = tv.ntv
  FROM tmp_zot_logrecord_tv AS tv
INNER JOIN l_game_key AS gk ON tv.game_key = gk.game_key
 WHERE l.game_key_id = gk.id;
 
UPDATE zot_milestone AS l
   SET ntv = tv.ntv
  FROM tmp_zot_milestone_tv AS tv
INNER JOIN l_game_key AS gk ON tv.game_key = gk.game_key
 WHERE l.game_key_id = gk.id
   AND tv.rstart = l.rstart;
 
   
