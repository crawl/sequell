DROP TABLE IF EXISTS logrecord;
DROP TABLE IF EXISTS logfiles;

CREATE TABLE logfiles (
    file VARCHAR(150) PRIMARY KEY
);

CREATE TABLE logrecord (
    id INT AUTO_INCREMENT,
    offset BIGINT,
    file VARCHAR(150),
    src CHAR(5),
    v VARCHAR(8),
    cv VARCHAR(8),
    lv VARCHAR(8),
    sc BIGINT,
    pname VARCHAR(20),
    uid INT,
    race VARCHAR(20),
    crace VARCHAR(20),
    cls VARCHAR(20),
    charabbrev CHAR(4),
    xl INT,
    sk VARCHAR(16),
    sklev INT,
    title VARCHAR(50),
    ktyp VARCHAR(20),
    killer VARCHAR(50),
    ckiller VARCHAR(50),
    kmod VARCHAR(50),
    kaux VARCHAR(255),
    ckaux VARCHAR(255),
    place VARCHAR(16),
    br VARCHAR(16),
    lvl INT,
    ltyp VARCHAR(16),
    hp INT,
    mhp INT,
    mmhp INT,
    dam INT,
    sstr INT,
    sint INT,
    sdex INT,
    god VARCHAR(50),
    piety INT,
    pen INT,
    wiz INT,
    tstart DATETIME,
    tend DATETIME,
    dur BIGINT,
    turn BIGINT,
    urune INT,
    nrune INT,
    tmsg VARCHAR(255),
    vmsg VARCHAR(255),
    splat CHAR(1),
    PRIMARY KEY (id)
);

CREATE INDEX ind_foffset on logrecord (file, offset);