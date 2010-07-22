DROP TABLE IF EXISTS logrecord;
DROP TABLE IF EXISTS logfiles;
DROP TABLE IF EXISTS milestone;
DROP TABLE IF EXISTS milestone_files;

CREATE TABLE logfiles (
    file VARCHAR(150) PRIMARY KEY
);

CREATE TABLE milestone_files (
    file VARCHAR(150) PRIMARY KEY
);

CREATE TABLE logrecord (
    id BIGINT AUTO_INCREMENT,
    offset BIGINT,
    file VARCHAR(150),
    -- y for alpha, anything else otherwise.
    alpha CHAR(1),

    src CHAR(3),

    -- Non housekeeping fields:
    game VARCHAR(10),
    
    version VARCHAR(10),
    cversion VARCHAR(10),

    points BIGINT,

    branch VARCHAR(20),
    bdepth INT,
    place VARCHAR(30),
    placename VARCHAR(80),

    amulet CHAR(1) DEFAULT 'N',

    maxlvl INT,
    hp INT,
    maxhp INT,
    deaths INT DEFAULT 0,
    deathdate DATETIME,
    birthdate DATETIME,
    
    pname VARCHAR(20),
    
    prole CHAR(3),
    prace CHAR(3),
    pgender CHAR(3),
    palign CHAR(3),
    pgender0 CHAR(3),
    palign0 CHAR(3),

    -- Death message as in death field.
    deathmsg VARCHAR(150),

    -- quit, killed, petrified
    ktype  VARCHAR(30),
    killer VARCHAR(80),
    ckiller VARCHAR(80),

    -- while <yadda>
    kstate VARCHAR(80),

    helpless CHAR(1),
    praying  CHAR(1),

    conduct VARCHAR(150),
    nconduct TINYINT DEFAULT 0,
    achieve VARCHAR(150),
    nachieve TINYINT DEFAULT 0,

    turns BIGINT,
        
    realtime BIGINT,

    starttime DATETIME,
    endtime DATETIME,
  
    PRIMARY KEY (id)
);

CREATE INDEX ind_foffset ON logrecord (file, offset);
CREATE INDEX ind_milelocate ON logrecord (src, pname, starttime);

CREATE TABLE milestone (
    id BIGINT AUTO_INCREMENT,
    offset BIGINT,
    file VARCHAR(150),
    alpha CHAR(1),
    src CHAR(5),

    -- The actual game that this milestone is linked with.
    game_id BIGINT,

    game VARCHAR(10),
    
    version VARCHAR(10),
    cversion VARCHAR(10),

    branch VARCHAR(20),
    bdepth INT,
    place VARCHAR(30),
    placename VARCHAR(80),

    amulet CHAR(1) DEFAULT 'N',
    
    maxlvl INT,
    hp INT,
    maxhp INT,
    deaths INT DEFAULT 0,
    deathdate DATETIME,
    birthdate DATETIME,

    pname VARCHAR(20),
    
    prole CHAR(3),
    prace CHAR(3),
    pgender CHAR(3),
    palign CHAR(3),
    pgender0 CHAR(3),
    palign0 CHAR(3),

    -- Death message as in 'death' field.
    deathmsg VARCHAR(50),

    -- 'quit', 'killed', 'petrified'
    ktyp   VARCHAR(30),
    killer VARCHAR(50),

    helpless CHAR(1),
    praying  CHAR(1),

    conduct VARCHAR(150),
    nconduct TINYINT DEFAULT 0,
    achieve VARCHAR(150),
    nachieve TINYINT DEFAULT 0,

    turns BIGINT,
        
    realtime BIGINT,

    starttime DATETIME,
    currenttime DATETIME,

    mtype VARCHAR(20),

    -- Human readable message.
    mdesc VARCHAR(80),

    -- Set to achievement or thing wished for, or for shoplifting, the
    -- name of the shopkeeper.
    mobj VARCHAR(50),

    shop VARCHAR(25) DEFAULT '',
    
    shoplifted INT DEFAULT 0,

    wish_count INT DEFAULT 0,

    PRIMARY KEY(id),
    FOREIGN KEY (game_id) REFERENCES logrecord (id)
    ON DELETE SET NULL
);
CREATE INDEX mile_lookup_ext ON milestone (mtype, mobj);
CREATE INDEX mile_ind_foffset ON milestone (file, offset);
CREATE INDEX mile_lookup ON milestone (game_id, mtype);
CREATE INDEX mile_game_id ON milestone (game_id);