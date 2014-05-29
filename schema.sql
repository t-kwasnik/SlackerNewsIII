CREATE TABLE articles (
  article_id serial PRIMARY KEY,
  title text,
  url text,
  description text,
  time date
);

CREATE TABLE comments (
  comment_id serial PRIMARY KEY,
  parent_comment integer,
  article_id integer,
  comment text,
  time date
);

CREATE RULE update_parent_comment AS
ON INSERT TO comments
DO UPDATE comments SET parent_comment = comment_id
WHERE parent_comment = -1;


