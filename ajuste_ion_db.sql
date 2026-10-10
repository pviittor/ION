-- Ajusta o ion_db local ao que o backend atual espera.
-- Só adiciona coisas: nenhuma tabela, coluna ou linha existente é apagada ou alterada.

-- credenciais: colunas usadas pela tela de conexão e pelo chat
ALTER TABLE credenciais ADD COLUMN IF NOT EXISTS api_key TEXT;
ALTER TABLE credenciais ADD COLUMN IF NOT EXISTS model TEXT;
ALTER TABLE credenciais ADD COLUMN IF NOT EXISTS tipo_banco VARCHAR(50);

-- o backend faz INSERT ... ON CONFLICT (idusuario), que exige UNIQUE
ALTER TABLE credenciais ADD CONSTRAINT credenciais_idusuario_key UNIQUE (idusuario);

-- reset_password: usada pela recuperação de senha por e-mail
CREATE TABLE IF NOT EXISTS reset_password (
  id SERIAL PRIMARY KEY,
  idusuario INTEGER NOT NULL REFERENCES usuarios(idusuario) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL,
  token VARCHAR(255) NOT NULL,
  token_expiracao TIMESTAMPTZ NOT NULL,
  data_criacao TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_utilizacao TIMESTAMPTZ,
  status VARCHAR(20) NOT NULL DEFAULT 'ativo',
  tentativas_uso INTEGER NOT NULL DEFAULT 0
);
