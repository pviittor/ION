import { Request, Response } from 'express';
import { pool } from '../database/db';

export const deleteUser = async (req: Request, res: Response): Promise<void> => {
  const { idusuario } = req.params; // ID do usuário a ser excluído

  try {
    const result = await pool.query('DELETE FROM usuarios WHERE idusuario = $1 RETURNING idusuario', [idusuario]);

    if (result.rowCount === 0) {
      res.status(404).json({ mensagem: 'Usuário não encontrado.' });
      return; 
    }

    res.status(200).json({ mensagem: 'Conta excluída com sucesso!' });
  } catch (error) {
    console.error('Erro ao excluir conta:', error);
    res.status(500).json({ mensagem: 'Erro interno do servidor.' });
  }
};

