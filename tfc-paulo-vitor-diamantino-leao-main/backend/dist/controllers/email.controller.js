"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resetPasswordWithToken = exports.verifyResetToken = exports.sendPasswordResetEmail = void 0;
const nodemailer_1 = __importDefault(require("nodemailer"));
const db_1 = require("../database/db");
const moment_1 = __importDefault(require("moment"));
require("moment-timezone");
const transporter = nodemailer_1.default.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    }
});
const sendPasswordResetEmail = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) {
            res.status(400).json({ error: 'Email é obrigatório' });
            return;
        }
        // Verificar se o usuário existe
        const userQuery = 'SELECT idusuario, nome FROM usuarios WHERE email = $1';
        const userResult = await db_1.pool.query(userQuery, [email]);
        if (userResult.rows.length === 0) {
            res.status(404).json({ error: 'Email não cadastrado' });
            return;
        }
        const { idusuario, nome } = userResult.rows[0];
        console.log('Usuário encontrado:', idusuario);
        // Gerar código simples de 6 dígitos em vez de JWT
        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
        // Definir expiração usando moment-timezone (1 hora a partir de agora no timezone de Brasília)
        const tokenExpiracao = (0, moment_1.default)().tz('America/Sao_Paulo').add(1, 'hour').toDate();
        // Remover tokens antigos do usuário na nova tabela
        await db_1.pool.query('DELETE FROM reset_password WHERE idusuario = $1', [idusuario]);
        // Salvar novo código na tabela reset_password (com timezone explícito)
        const insertQuery = `
      INSERT INTO reset_password (idusuario, email, token, token_expiracao, data_criacao, status)
      VALUES ($1, $2, $3, $4, 
              CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo',
              'ativo')
      RETURNING id
    `;
        await db_1.pool.query(insertQuery, [idusuario, email, resetCode, tokenExpiracao]);
        // Configurar o email
        const mailOptions = {
            from: process.env.EMAIL_USER,
            to: email,
            subject: 'Ion - Redefinição de Senha',
            html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #333;">Redefinição de Senha - Ion</h2>
          <p>Olá, ${nome}!</p>
          <p>Você solicitou a redefinição de sua senha. Use o código abaixo no aplicativo Ion:</p>
          <div style="text-align: center; margin: 30px 0;">
            <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; border: 2px dashed #007bff;">
              <h3 style="color: #007bff; margin: 0; font-size: 24px; letter-spacing: 3px;">${resetCode}</h3>
              <p style="margin: 5px 0 0 0; color: #666; font-size: 12px;">Código de Redefinição</p>
            </div>
          </div>
          <p><strong>Este código é válido por 1 hora.</strong></p>
          <p>Abra o aplicativo Ion, vá no aplicativo e digite este código.</p>
          <p>Se você não solicitou esta redefinição, ignore este email.</p>
          <hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">
          <p style="color: #666; font-size: 12px;">Este é um email automático, não responda.</p>
        </div>
      `
        };
        // Enviar email
        await transporter.sendMail(mailOptions);
        res.status(200).json({
            message: 'Email de redefinição enviado com sucesso',
            tokenPreview: resetCode.substring(0, 6) // Only for debug
        });
    }
    catch (error) {
        console.error('Erro ao enviar email:', error);
        res.status(500).json({ error: 'Erro interno do servidor' });
    }
};
exports.sendPasswordResetEmail = sendPasswordResetEmail;
const verifyResetToken = async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) {
            res.status(400).json({ error: 'Codigo é obrigatório' });
            return;
        }
        // Buscar o token na nova tabela reset_password
        const query = `
      SELECT id, token, token_expiracao, idusuario, email, status, tentativas_uso
      FROM reset_password 
      WHERE token = $1
    `;
        const result = await db_1.pool.query(query, [token]);
        if (result.rows.length === 0) {
            res.status(400).json({ error: 'Código Inválido' });
            return;
        }
        const tokenData = result.rows[0];
        const expiracao = (0, moment_1.default)(tokenData.token_expiracao).tz('America/Sao_Paulo');
        const agora = (0, moment_1.default)().tz('America/Sao_Paulo');
        if (agora.isAfter(expiracao)) {
            await db_1.pool.query('UPDATE reset_password SET status = $1 WHERE id = $2', ['expirado', tokenData.id]);
            res.status(400).json({ error: 'Codigo expirado' });
            return;
        }
        // Incrementar tentativas de uso
        await db_1.pool.query('UPDATE reset_password SET tentativas_uso = tentativas_uso + 1 WHERE id = $1', [tokenData.id]);
        // Token válido
        res.status(200).json({
            message: 'Codigo válido',
            idusuario: tokenData.idusuario,
            email: tokenData.email
        });
    }
    catch (error) {
        console.error('Erro ao verificar Codigo:', error);
        res.status(500).json({ error: 'Erro interno do servidor' });
    }
};
exports.verifyResetToken = verifyResetToken;
const resetPasswordWithToken = async (req, res) => {
    try {
        const { token, newPassword, confirmPassword } = req.body;
        if (!token || !newPassword || !confirmPassword) {
            res.status(400).json({ error: 'Todos os campos são obrigatórios' });
            return;
        }
        if (newPassword !== confirmPassword) {
            res.status(400).json({ error: 'As senhas não coincidem' });
            return;
        }
        // Buscar e verificar o token na nova tabela
        const tokenQuery = 'SELECT * FROM reset_password WHERE token = $1 AND status = $2';
        const tokenResult = await db_1.pool.query(tokenQuery, [token, 'ativo']);
        if (tokenResult.rows.length === 0) {
            res.status(400).json({ error: 'Codigo não encontrado ou inválido' });
            return;
        }
        const tokenData = tokenResult.rows[0];
        // Verificar expiração
        const expiracao = (0, moment_1.default)(tokenData.token_expiracao);
        const agora = (0, moment_1.default)();
        if (agora.isAfter(expiracao)) {
            await db_1.pool.query('UPDATE reset_password SET status = $1 WHERE id = $2', ['expirado', tokenData.id]);
            res.status(400).json({ error: 'Codigo expirado' });
            return;
        }
        // Criptografar nova senha
        const bcrypt = require('bcrypt');
        const senhaCriptografada = await bcrypt.hash(newPassword, 10);
        // Atualizar senha do usuário
        const updateQuery = 'UPDATE usuarios SET senha = $1 WHERE idusuario = $2';
        await db_1.pool.query(updateQuery, [senhaCriptografada, tokenData.idusuario]);
        // Marcar token como usado
        await db_1.pool.query('UPDATE reset_password SET status = $1, data_utilizacao = $2 WHERE id = $3', ['usado', (0, moment_1.default)().tz('America/Sao_Paulo').toDate(), tokenData.id]);
        res.status(200).json({
            message: 'Senha redefinida com sucesso'
        });
    }
    catch (error) {
        console.error('Erro ao redefinir senha:', error);
        res.status(500).json({ error: 'Erro interno do servidor' });
    }
};
exports.resetPasswordWithToken = resetPasswordWithToken;
