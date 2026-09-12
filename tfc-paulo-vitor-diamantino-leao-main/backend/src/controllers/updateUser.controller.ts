import { Request, Response } from 'express';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';

export const updateUser = async (req: Request, res: Response): Promise<void> => {
  const { idusuario } = req.params;
  const { nome, sobrenome, telefone, senha, confirmarSenha } = req.body;

  // Adicione este log para debug
  console.log('Dados recebidos:', { nome, sobrenome, telefone, senha: senha ? '***' : undefined, confirmarSenha: confirmarSenha ? '***' : undefined });

  try {
    // Verifica se pelo menos um campo foi fornecido para atualização
    if (!nome && !sobrenome && !telefone && !senha) {
      res.status(400).json({ mensagem: 'Pelo menos um campo deve ser fornecido para atualização.' });
      return;
    }

    // Se apenas senha está sendo atualizada, verifica se confirmarSenha foi fornecida
    if (senha && !confirmarSenha) {
      res.status(400).json({ mensagem: 'Confirmação de senha é obrigatória ao alterar a senha.' });
      return;
    }

    // Verifica se as senhas correspondem
    if (senha && senha !== confirmarSenha) {
      res.status(400).json({ mensagem: 'As senhas não coincidem.' });
      return;
    }

    // Busca os dados atuais do usuário
    const currentUserQuery = 'SELECT nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1';
    const currentUserResult = await pool.query(currentUserQuery, [idusuario]);
    
    if (currentUserResult.rowCount === 0) {
      res.status(404).json({ mensagem: 'Usuário não encontrado.' });
      return;
    }

    const currentUser = currentUserResult.rows[0];

    // Se a senha foi fornecida, criptografa a nova senha
    let senhaCriptografada = undefined;
    if (senha) {
      senhaCriptografada = await bcrypt.hash(senha, 10);
    }

    // Usa os valores fornecidos ou mantém os valores atuais
    const nomeAtualizado = nome || currentUser.nome;
    const sobrenomeAtualizado = sobrenome || currentUser.sobrenome;
    const telefoneAtualizado = telefone || currentUser.telefone;

    // Atualiza os dados no banco de dados
    const query = `
      UPDATE usuarios
      SET nome = $1, sobrenome = $2, telefone = $3${senha ? ', senha = $4' : ''}
      WHERE idusuario = $${senha ? '5' : '4'}
      RETURNING idusuario
    `;
    
    const params = senha 
      ? [nomeAtualizado, sobrenomeAtualizado, telefoneAtualizado, senhaCriptografada, idusuario]
      : [nomeAtualizado, sobrenomeAtualizado, telefoneAtualizado, idusuario];

    const result = await pool.query(query, params);

    // Verifica se o usuário foi encontrado e atualizado
    if (result.rowCount === 0) {
      res.status(404).json({ mensagem: 'Usuário não encontrado.' });
      return;
    }

    res.status(200).json({
      mensagem: 'Dados do usuário atualizados com sucesso.',
      idusuario: result.rows[0].idusuario
    });
  } catch (error) {
    console.error('Erro ao atualizar dados do usuário:', error);
    res.status(500).json({ mensagem: 'Erro interno do servidor.' });
  }
};

