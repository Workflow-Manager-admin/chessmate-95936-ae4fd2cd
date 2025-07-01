-- Chess Web Application Database Schema for PostgreSQL
-- Covers: User profiles, authentication, ongoing/completed games, move history, constraints and indexes.
-- PUBLIC_INTERFACE: This schema is to be managed by the backend via ORM/SQL and accessible for all CRUD operations.

BEGIN;

-- ==========================
-- 1. USERS & AUTHENTICATION
-- ==========================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(32) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    full_name VARCHAR(120),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Store password hashes + support for authentication provider (for possible OAuth in future)
CREATE TABLE auth_credentials (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(128) NOT NULL,
    -- For extensibility: local or oauth provider
    provider VARCHAR(32) DEFAULT 'local',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for fast authentication/account lookup
CREATE INDEX idx_auth_user ON auth_credentials(user_id);

-- ==========================
-- 2. GAMES TABLE
-- ==========================
CREATE TABLE games (
    id SERIAL PRIMARY KEY,
    player_white_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    player_black_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    ai_opponent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(32) NOT NULL DEFAULT 'ongoing', -- ongoing, finished, aborted
    winner VARCHAR(10), -- 'white', 'black', 'draw', NULL if ongoing
    result_reason VARCHAR(120),  -- e.g., 'checkmate', 'resignation', 'timeout'
    last_move_at TIMESTAMP WITH TIME ZONE
);

-- For displaying games played by a user quickly
CREATE INDEX idx_games_player_white ON games(player_white_id);
CREATE INDEX idx_games_player_black ON games(player_black_id);
CREATE INDEX idx_games_status ON games(status);

-- ==========================
-- 3. MOVE HISTORY
-- ==========================
CREATE TABLE moves (
    id SERIAL PRIMARY KEY,
    game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    move_number INTEGER NOT NULL,           -- 1, 2, 3, ...
    move_san VARCHAR(16) NOT NULL,          -- Standard Algebraic Notation e.g. Nf3, e4, O-O
    move_uci VARCHAR(8),                    -- UCI format (e.g. e2e4)
    player_color VARCHAR(5) NOT NULL,       -- 'white' or 'black'
    played_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    played_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    comment TEXT
);

-- Quickly query move list for game, enforcing proper ordering
CREATE INDEX idx_moves_game_move_number ON moves(game_id, move_number);

-- Ensure move number ordering per game (no duplicate move numbers in a game)
ALTER TABLE moves
    ADD CONSTRAINT moves_unique_game_move UNIQUE(game_id, move_number);

-- ==========================
-- 4. GAME ARCHIVE & INTEGRITY
-- ==========================

-- Store full (final) games in PGN (Portable Game Notation) (optional, for download/view)
CREATE TABLE game_archives (
    id SERIAL PRIMARY KEY,
    game_id INTEGER NOT NULL UNIQUE REFERENCES games(id) ON DELETE CASCADE,
    pgn TEXT NOT NULL,
    archived_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================
-- 5. UTILITY/ADMIN TABLES (optional)
-- ==========================

-- User's ranking/elo (optional, can be extended later)
CREATE TABLE user_rankings (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    elo_rating INTEGER DEFAULT 1200,
    games_played INTEGER DEFAULT 0,
    games_won INTEGER DEFAULT 0,
    games_lost INTEGER DEFAULT 0,
    games_drawn INTEGER DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================
-- 6. DATA INTEGRITY
-- ==========================

-- Ensure usernames and emails are unique (already set above), but reinforce with constraints:
ALTER TABLE users ADD CONSTRAINT email_unique UNIQUE(email);

-- Trigger to update 'updated_at' automatically on users table
CREATE OR REPLACE FUNCTION update_users_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE PROCEDURE update_users_updated_at_column();

COMMIT;
