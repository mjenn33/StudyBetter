CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens(user_id);

CREATE TYPE visibility AS ENUM ('public', 'unlisted', 'private');

CREATE TABLE quizzes (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  tags text[] NOT NULL DEFAULT '{}',
  language text,
  visibility visibility NOT NULL DEFAULT 'private',
  version integer NOT NULL CHECK (version >= 1),
  item_count integer NOT NULL DEFAULT 0,
  download_count integer NOT NULL DEFAULT 0,
  document jsonb NOT NULL,
  search_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '') || ' ' || array_to_string(tags, ' '))) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX quizzes_search_idx ON quizzes USING gin(search_vector);
CREATE INDEX quizzes_owner_idx ON quizzes(owner_id);

CREATE TABLE decks (LIKE quizzes INCLUDING ALL);
ALTER TABLE decks ADD CONSTRAINT decks_owner_fk FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX decks_search_idx ON decks USING gin(search_vector);
