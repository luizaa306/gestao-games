DROP VIEW IF EXISTS vw_cronograma_partidas;
DROP VIEW IF EXISTS vw_painel_principal;

DROP TABLE IF EXISTS historico_partidas;
DROP TABLE IF EXISTS partidas;
DROP TABLE IF EXISTS torneios;
DROP TABLE IF EXISTS jogos;
DROP TABLE IF EXISTS jogadores;

DROP FUNCTION IF EXISTS fn_buscar_jogadores(TEXT);
DROP FUNCTION IF EXISTS fn_validar_partida();
DROP FUNCTION IF EXISTS fn_registrar_historico_partida();

CREATE TABLE jogadores (
    id_jogador SERIAL PRIMARY KEY,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    nome VARCHAR(100) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE jogos (
    id_jogo SERIAL PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL UNIQUE,
    categoria VARCHAR(50) NOT NULL
);


CREATE TABLE torneios (
    id_torneio SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    id_jogo INT NOT NULL REFERENCES jogos(id_jogo),
    data_inicio DATE NOT NULL,
    data_fim DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Inscricao'
        CHECK (status IN ('Inscricao', 'Em andamento', 'Encerrado')),
    CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

CREATE TABLE partidas (
    id_partida SERIAL PRIMARY KEY,
    id_torneio INT NOT NULL REFERENCES torneios(id_torneio),
    id_jogador_responsavel INT NOT NULL REFERENCES jogadores(id_jogador),
    adversario VARCHAR(50) NOT NULL,
    data_partida TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Agendada'
        CHECK (status IN ('Agendada', 'Em andamento', 'Concluida', 'Cancelada')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE historico_partidas (
    id_historico SERIAL PRIMARY KEY,
    id_partida INT NOT NULL REFERENCES partidas(id_partida),
    acao VARCHAR(30) NOT NULL,
    data_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descricao TEXT NOT NULL
);

INSERT INTO historico_partidas (id_partida, acao, descricao)
SELECT
    id_partida,
    'CRIACAO',
    'Partida criada e agendada.'
FROM partidas;

INSERT INTO jogadores (nickname, email, nome, ativo) VALUES
('PixelWolf', 'pixelwolf@email.com', 'Pedro Almeida', TRUE),
('LunaPlay', 'lunaplay@email.com', 'Luna Martins', TRUE),
('NinjaSC', 'ninjas@email.com', 'Rafael Souza', TRUE),
('ByteQueen', 'bytequeen@email.com', 'Marina Costa', FALSE);

INSERT INTO jogos (titulo, categoria) VALUES
('Valorant', 'FPS'),
('League of Legends', 'MOBA'),
('Rocket League', 'Esporte');

INSERT INTO torneios (nome, id_jogo, data_inicio, data_fim, status) VALUES
('Copa Valorant SC', 1, '2026-12-05', '2026-12-07', 'Inscricao'),
('Liga LoL Escolar', 2, '2026-12-10', '2026-12-15', 'Inscricao'),
('Rocket Cup', 3, '2026-12-20', '2026-12-21', 'Em andamento');

INSERT INTO partidas
(id_torneio, id_jogador_responsavel, adversario, data_partida, status)
VALUES
(1, 1, 'Equipe Aurora', '2026-12-05 14:00', 'Agendada'),
(2, 2, 'Equipe Fenix', '2026-12-10 16:00', 'Agendada'),
(3, 3, 'Equipe Turbo', '2026-12-20 10:00', 'Em andamento');

CREATE OR REPLACE FUNCTION fn_buscar_jogadores(p_termo TEXT)
RETURNS TABLE (
    id_jogador INT,
    nickname VARCHAR,
    email VARCHAR,
    nome VARCHAR,
    ativo BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        j.id_jogador,
        j.nickname,
        j.email,
        j.nome,
        j.ativo
    FROM jogadores AS j
    WHERE j.nickname ILIKE '%' || p_termo || '%'
       OR j.email ILIKE '%' || p_termo || '%';
END;
$$;


CREATE OR REPLACE FUNCTION fn_validar_partida()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM jogadores
        WHERE id_jogador = NEW.id_jogador_responsavel
          AND ativo = TRUE
    ) THEN
        RAISE EXCEPTION
        'O jogador responsavel nao existe ou esta inativo.';
    END IF;

    NEW.created_at := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_partida
BEFORE INSERT ON partidas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_partida();



CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT
    p.id_partida,
    t.nome AS torneio,
    jg.titulo AS jogo,
    jg.categoria,
    p.adversario,
    p.data_partida,
    p.status,
    j.nickname AS jogador_responsavel
FROM partidas AS p
JOIN torneios AS t
    ON p.id_torneio = t.id_torneio
JOIN jogos AS jg
    ON t.id_jogo = jg.id_jogo
JOIN jogadores AS j
    ON p.id_jogador_responsavel = j.id_jogador;

    CREATE OR REPLACE VIEW vw_cronograma_partidas AS
SELECT
    p.id_partida,
    t.nome AS torneio,
    jg.titulo AS jogo,
    p.data_partida,
    p.status AS status_partida,
    p.adversario,
    j.nickname AS jogador_responsavel
FROM partidas AS p
JOIN torneios AS t
    ON p.id_torneio = t.id_torneio
JOIN jogos AS jg
    ON t.id_jogo = jg.id_jogo
JOIN jogadores AS j
    ON p.id_jogador_responsavel = j.id_jogador
ORDER BY p.data_partida ASC;