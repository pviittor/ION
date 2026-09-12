"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifySMSCode = exports.sendSMSCode = void 0;
const twilio_1 = __importDefault(require("twilio"));
const db_1 = require("../database/db");
const moment_1 = __importDefault(require("moment"));
const client = (0, twilio_1.default)(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const sendSMSCode = async (req, res) => {
    try {
        const { phoneNumber } = req.body;
        if (!phoneNumber) {
            res.status(400).json({ error: 'Número de telefone é obrigatório' });
            return;
        }
        // Limpar o número de telefone (remover caracteres especiais e código do país)
        let numeroLimpo = phoneNumber.replace(/\D/g, '');
        // Se o número começar com 55 (código do Brasil), remover
        if (numeroLimpo.startsWith('55') && numeroLimpo.length === 13) {
            numeroLimpo = numeroLimpo.substring(2); // Remove os primeiros 2 dígitos (55)
        }
        console.log('Número original:', phoneNumber);
        console.log('Número processado:', numeroLimpo);
        // Buscar usuário pelo telefone
        const userQuery = 'SELECT idusuario FROM usuarios WHERE telefone = $1';
        const userResult = await db_1.pool.query(userQuery, [numeroLimpo]);
        if (userResult.rows.length === 0) {
            console.log('Telefone não encontrado no banco:', numeroLimpo);
            res.status(400).json({ error: 'Telefone não cadastrado no sistema' });
            return;
        }
        const idusuario = userResult.rows[0].idusuario;
        console.log('Usuário encontrado:', idusuario);
        // Gerar código de 6 dígitos
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
        // Definir expiração de 15 minutos
        const codigoExpiracao = (0, moment_1.default)().add(15, 'minutes').toISOString();
        // Enviar SMS via Twilio (usar o número original com +55)
        await client.messages.create({
            body: `Ion: Seu codigo de verificao é: ${verificationCode}. Valido por 15 minutos.`,
            from: process.env.TWILIO_PHONE_NUMBER,
            to: phoneNumber // Usar o número original com +55
        });
        // Remover códigos antigos do usuário
        await db_1.pool.query('DELETE FROM recuperar_senha WHERE idusuario = $1', [idusuario]);
        // Salvar novo código na tabela recuperar_senha
        const insertQuery = `
      INSERT INTO recuperar_senha (codigo, codigo_expiracao, idusuario)
      VALUES ($1, $2, $3)
      RETURNING *
    `;
        const insertResult = await db_1.pool.query(insertQuery, [verificationCode, codigoExpiracao, idusuario]);
        console.log('Código SMS salvo no banco:', insertResult.rows[0]);
        res.status(200).json({
            message: 'Código enviado com sucesso',
            phoneNumber: phoneNumber.replace(/.(?=.{4})/g, '*') // Mascarar número para segurança
        });
    }
    catch (error) {
        console.error('Erro ao enviar SMS:', error);
        res.status(500).json({ error: 'Erro interno do servidor' });
    }
};
exports.sendSMSCode = sendSMSCode;
const verifySMSCode = async (req, res) => {
    try {
        const { code } = req.body;
        if (!code) {
            res.status(400).json({ error: 'Código é obrigatório' });
            return;
        }
        // Buscar o código na tabela recuperar_senha
        const query = `
      SELECT codigo, codigo_expiracao, idusuario
      FROM recuperar_senha 
      WHERE codigo = $1
    `;
        const result = await db_1.pool.query(query, [code]);
        if (result.rows.length === 0) {
            res.status(400).json({ error: 'Código não encontrado' });
            return;
        }
        const storedData = result.rows[0];
        const expiracao = (0, moment_1.default)(storedData.codigo_expiracao);
        const agora = (0, moment_1.default)();
        // Verificar se o código expirou
        if (agora.isAfter(expiracao)) {
            // Remover código expirado
            await db_1.pool.query('DELETE FROM recuperar_senha WHERE codigo = $1', [code]);
            res.status(400).json({ error: 'Código expirado' });
            return;
        }
        // Código válido - remover da tabela
        await db_1.pool.query('DELETE FROM recuperar_senha WHERE codigo = $1', [code]);
        // Buscar dados do usuário
        const userQuery = 'SELECT telefone FROM usuarios WHERE idusuario = $1';
        const userResult = await db_1.pool.query(userQuery, [storedData.idusuario]);
        if (userResult.rows.length === 0) {
            res.status(400).json({ error: 'Usuário não encontrado' });
            return;
        }
        const phoneNumber = userResult.rows[0].telefone;
        // Gerar JWT
        const jwt = require('jsonwebtoken');
        const token = jwt.sign({ phoneNumber, verified: true, idusuario: storedData.idusuario }, process.env.JWT_SECRET, { expiresIn: '24h' });
        res.status(200).json({
            message: 'Código verificado com sucesso',
            token,
            phoneNumber,
            idusuario: storedData.idusuario
        });
    }
    catch (error) {
        console.error('Erro ao verificar código:', error);
        res.status(500).json({ error: 'Erro interno do servidor' });
    }
};
exports.verifySMSCode = verifySMSCode;
