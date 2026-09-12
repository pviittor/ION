import { Request, Response } from 'express';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';

export const register = async (req: Request, res: Response): Promise<void> => {
  const { nome, sobrenome, email, telefone, senha } = req.body;

  try {
    // Verifica se todos os campos foram preenchidos
    if (!nome || !sobrenome || !email || !telefone || !senha) {
      res.status(400).json({ mensagem: 'Todos os campos são obrigatórios.' });
      return;
    }

    // Verifica se já existe usuário com o mesmo email
    const existingUser = await pool.query('SELECT 1 FROM usuarios WHERE email = $1', [email]);
    if (existingUser.rowCount && existingUser.rowCount > 0) {
      res.status(400).json({ mensagem: 'Email já cadastrado.' });
      return;
    }

    // Criptografa a senha
    const senhaCriptografada = await bcrypt.hash(senha, 10);

    // Insere no banco de dados
    const result = await pool.query(
      `INSERT INTO usuarios (nome, sobrenome, email, telefone, senha)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING idusuario`,
      [nome, sobrenome, email, telefone, senhaCriptografada]
    );

    const novoUsuarioId = result.rows[0].idusuario;

    res.status(201).json({
      mensagem: 'Usuário cadastrado com sucesso',
      idusuario: novoUsuarioId
    });
  } catch (error) {
    console.error('Erro ao cadastrar usuário:', error);
    res.status(500).json({ mensagem: 'Erro interno do servidor.' });
  }
};
