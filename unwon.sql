CREATE OR REPLACE VIEW distinct_combos
AS SELECT DISTINCT charabbrev FROM logrecord;

CREATE OR REPLACE VIEW unwon_combos
AS SELECT dc.charabbrev FROM distinct_combos dc
WHERE NOT EXISTS (SELECT * FROM logrecord lr WHERE
                  lr.charabbrev = dc.charabbrev
                  AND ktyp = 'winning');

SELECT lr.charabbrev combo, COUNT(*) games
FROM logrecord lr, unwon_combos uw
WHERE lr.charabbrev = uw.charabbrev
  AND lr.ktyp != 'quitting'
GROUP BY lr.charabbrev
ORDER BY games DESC;