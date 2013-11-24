CREATE TABLE terms (id INTEGER PRIMARY KEY AUTOINCREMENT,
                    term TEXT COLLATE NOCASE);
CREATE INDEX terms_term ON terms (term);

CREATE TABLE definitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  term_id INTEGER,
  definition STRING,
  seq INTEGER,
  FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
);

CREATE INDEX definitions_definition ON definitions (definition);
CREATE INDEX definitions_term_id ON definitions (term_id);
                          
