DROP TABLE IF EXISTS milestone;
DROP TABLE IF EXISTS spr_milestone;
DROP TABLE IF EXISTS zot_milestone;
DROP TABLE IF EXISTS milestone_files;
DROP TABLE IF EXISTS logrecord;
DROP TABLE IF EXISTS spr_logrecord;
DROP TABLE IF EXISTS zot_logrecord;
DROP TABLE IF EXISTS logfiles;

DROP SEQUENCE IF EXISTS spr_logrecord_seq;
DROP SEQUENCE IF EXISTS zot_logrecord_seq;
DROP SEQUENCE IF EXISTS spr_milestone_seq;
DROP SEQUENCE IF EXISTS zot_milestone_seq;

CREATE TABLE logfiles (
    file CITEXT PRIMARY KEY
);

CREATE TABLE milestone_files (
    file CITEXT PRIMARY KEY
);

CREATE TABLE logrecord (
    id SERIAL,
    file_offset BIGINT,
    file CITEXT,
    -- 'y' for alpha, anything else otherwise.
    alpha CITEXT,
    src CITEXT,
    v CITEXT,
    cv CITEXT,
    lv CITEXT,
    sc BIGINT,
    pname CITEXT,
    uid INT,
    race CITEXT,
    crace CITEXT,
    cls CITEXT,
    charabbrev CITEXT,
    xl INT,
    sk CITEXT,
    sklev INT,
    title CITEXT,
    ktyp CITEXT,
    killer CITEXT,
    ckiller CITEXT,
    ikiller CITEXT,
    kpath CITEXT,
    kmod CITEXT,
    kaux CITEXT,
    ckaux CITEXT,
    place CITEXT,
    mapname CITEXT,
    mapdesc CITEXT,
    br CITEXT,
    lvl INT,
    ltyp CITEXT,
    hp INT,
    mhp INT,
    mmhp INT,
    dam INT,
    sstr INT,
    sint INT,
    sdex INT,
    god CITEXT,
    piety INT,
    pen INT,
    wiz INT,
    tstart TIMESTAMP,
    tend TIMESTAMP,
    rstart CITEXT,
    rend CITEXT,
    dur BIGINT,
    turn BIGINT,
    urune INT,
    nrune INT,
    tmsg CITEXT,
    vmsg CITEXT,
    splat CITEXT,
    tiles CITEXT,

    -- How many times it's been played on FooTV
    ntv INT DEFAULT 0,
    
    PRIMARY KEY (id)
);
CREATE INDEX ind_foffset ON logrecord (file, file_offset);
CREATE INDEX ind_milelocate ON logrecord (src, pname, rstart);

CREATE TABLE spr_logrecord AS
SELECT * FROM logrecord LIMIT 1;
TRUNCATE TABLE spr_logrecord;
CREATE SEQUENCE spr_logrecord_seq;
ALTER TABLE spr_logrecord ALTER COLUMN id SET DEFAULT NEXTVAL('spr_logrecord_seq');
ALTER TABLE spr_logrecord ADD PRIMARY KEY (id);
CREATE INDEX spr_ind_foffset ON spr_logrecord (file, file_offset);
CREATE INDEX spr_ind_milelocate ON spr_logrecord (src, pname, rstart);

CREATE TABLE zot_logrecord AS
SELECT * FROM logrecord LIMIT 1;
TRUNCATE TABLE zot_logrecord;
CREATE SEQUENCE zot_logrecord_seq;
ALTER TABLE zot_logrecord ALTER COLUMN id SET DEFAULT NEXTVAL('zot_logrecord_seq');
ALTER TABLE zot_logrecord ADD PRIMARY KEY (id);
CREATE INDEX zot_ind_foffset ON zot_logrecord (file, file_offset);
CREATE INDEX zot_ind_milelocate ON zot_logrecord (src, pname, rstart);

CREATE TABLE milestone (
    id SERIAL,
    file_offset BIGINT,
    file CITEXT,
    alpha CITEXT,
    tiles CITEXT,
    src CITEXT,

    -- The actual game that this milestone is linked with.
    game_id BIGINT,

    v CITEXT,
    cv CITEXT,
    pname CITEXT,
    race CITEXT,
    crace CITEXT,
    cls CITEXT,
    charabbrev CITEXT,
    xl INT,
    sk CITEXT,
    sklev INT,
    title CITEXT,
    place CITEXT,
    oplace CITEXT,

    br CITEXT,
    lvl INT,
    ltyp CITEXT,
    hp INT,
    mhp INT,
    mmhp INT,
    sstr INT,
    sint INT,
    sdex INT,
    god CITEXT,
    dur BIGINT,
    turn BIGINT,
    urune INT,
    nrune INT,
    ttime TIMESTAMP,
    rstart CITEXT,
    rtime CITEXT,

    -- Known milestones: abyss.enter, abyss.exit, rune, orb, ghost, uniq,
    -- uniq.ban, br.enter, br.end.
    verb CITEXT,
    noun CITEXT,

    -- The actual milestone message for Henzell to report.
    milestone CITEXT,

    -- How many times it's been played on FooTV
    ntv INT DEFAULT 0,

    PRIMARY KEY(id),
    FOREIGN KEY (game_id) REFERENCES logrecord (id)
    ON DELETE SET NULL
);
CREATE INDEX mile_lookup_ext ON milestone (verb, noun);
CREATE INDEX mile_ind_foffset ON milestone (file, file_offset);
CREATE INDEX mile_lookup ON milestone (game_id, verb);
CREATE INDEX mile_game_id ON milestone (game_id);

CREATE TABLE spr_milestone AS
SELECT * FROM milestone LIMIT 1;
TRUNCATE TABLE spr_milestone;
CREATE SEQUENCE spr_milestone_seq;
ALTER TABLE spr_milestone ALTER COLUMN id SET DEFAULT NEXTVAL('spr_milestone_seq');
ALTER TABLE spr_milestone ADD PRIMARY KEY (id);
CREATE INDEX spr_mile_lookup_ext ON spr_milestone (verb, noun);
CREATE INDEX spr_mile_ind_foffset ON spr_milestone (file, file_offset);
CREATE INDEX spr_mile_lookup ON spr_milestone (game_id, verb);
CREATE INDEX spr_mile_game_id ON spr_milestone (game_id);

CREATE TABLE zot_milestone AS
SELECT * FROM milestone LIMIT 1;
TRUNCATE TABLE zot_milestone;
CREATE SEQUENCE zot_milestone_seq;
ALTER TABLE zot_milestone ALTER COLUMN id SET DEFAULT NEXTVAL('zot_milestone_seq');
ALTER TABLE zot_milestone ADD PRIMARY KEY (id);
CREATE INDEX zot_mile_lookup_ext ON zot_milestone (verb, noun);
CREATE INDEX zot_mile_ind_foffset ON zot_milestone (file, file_offset);
CREATE INDEX zot_mile_lookup ON zot_milestone (game_id, verb);
CREATE INDEX zot_mile_game_id ON zot_milestone (game_id);

DROP TABLE IF EXISTS canary;
CREATE TABLE canary (
    last_update TIMESTAMP
);
