import { Request, Response } from 'express';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

export const login = async (req: Request, res: Response): Promise<void> => {
  const { email, senha } = req.body;

  try {
    const result = await pool.query('SELECT * FROM usuarios WHERE email = $1', [email]);

    if (result.rowCount === 0) {
      res.status(400).json({ mensagem: 'Usuário não encontrado' });
      return;
    }

    const usuario = result.rows[0];
    const senhaCorreta = await bcrypt.compare(senha, usuario.senha);

    if (!senhaCorreta) {
      res.status(401).json({ mensagem: 'Senha incorreta' });
      return;
    }

    const token = jwt.sign(
      { id: usuario.idusuario, email: usuario.email },
      process.env.JWT_SECRET as string,
      { expiresIn: '1d' }
    );

    res.status(200).json({
      mensagem: 'Login realizado com sucesso',
      token,
      usuario: {
        id: usuario.idusuario,
        nome: usuario.nome,
        email: usuario.email,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ mensagem: 'Erro interno do servidor' });
  }
};
