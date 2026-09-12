import { Request, Response } from 'express';
import { pool } from '../database/db';

export const getUser = async (req: Request, res: Response): Promise<void> => {
  const { idusuario } = req.params; // ID do usuário a ser recuperado

  try {
    // Recupera os dados do usuário no banco de dados
    const result = await pool.query(
      'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1',
      [idusuario]
    );

    // Verifica se o usuário foi encontrado
    if (result.rowCount === 0) {
      res.status(404).json({ mensagem: 'Usuário não encontrado.' });
      return;
    }

    // Retorna os dados do usuário
    const user = result.rows[0];
    res.status(200).json({
      usuario: {
        idusuario: user.idusuario,
        nome: user.nome,
        sobrenome: user.sobrenome,
        telefone: user.telefone,
      },
    });
  } catch (error) {
    console.error('Erro ao recuperar dados do usuário:', error);
    res.status(500).json({ mensagem: 'Erro interno do servidor.' });
  }
};

// Nova função para buscar usuário por telefone
export const getUserByPhone = async (req: Request, res: Response): Promise<void> => {
  const { telefone } = req.params; // Telefone do usuário a ser recuperado

  try {
    // Limpar o número de telefone (remover caracteres especiais e código do país)
    let numeroLimpo = telefone.replace(/\D/g, '');
    
    // Se o número começar com 55 (código do Brasil), remover
    if (numeroLimpo.startsWith('55') && numeroLimpo.length === 13) {
      numeroLimpo = numeroLimpo.substring(2); // Remove os primeiros 2 dígitos (55)
    }
    
    console.log('Buscando usuário por telefone:', numeroLimpo);
    
    // Recupera os dados do usuário no banco de dados pelo telefone
    const result = await pool.query(
      'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE telefone = $1',
      [numeroLimpo]
    );

    // Verifica se o usuário foi encontrado
    if (result.rowCount === 0) {
      res.status(404).json({ mensagem: 'Usuário não encontrado com este telefone.' });
      return;
    }

    // Retorna os dados do usuário
    const user = result.rows[0];
    res.status(200).json({
      id: user.idusuario, // Mantém compatibilidade com o frontend
      idusuario: user.idusuario,
      nome: user.nome,
      sobrenome: user.sobrenome,
      telefone: user.telefone,
    });
  } catch (error) {
    console.error('Erro ao recuperar dados do usuário por telefone:', error);
    res.status(500).json({ mensagem: 'Erro interno do servidor.' });
  }
};
