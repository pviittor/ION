"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.obterCredenciaisDescriptografadas = exports.buscarPorUsuario = exports.atualizarVanna = exports.criar = void 0;
const db_1 = require("../database/db");
const crypto_util_1 = require("../utils/crypto.util");
const criar = async (req, res) => {
    const { idusuario, dominio_banco, porta_banco, nome_banco, nome_usuario, senha_usuario, tipo_banco } = req.body;
    if (!idusuario || !dominio_banco || !porta_banco || !nome_banco || !nome_usuario || !senha_usuario || !tipo_banco) {
        res.status(400).json({ mensagem: 'Todos os campos são obrigatórios.' });
        return;
    }
    // Validar se tipo_banco é uma das opções válidas
    if (tipo_banco !== 'postgresql' && tipo_banco !== 'mysql') {
        res.status(400).json({ mensagem: 'Tipo de banco deve ser PostgreSQL ou MySQL.' });
        return;
    }
    try {
        // Usar criptografia reversível para senha do banco (não bcrypt)
        const senhaBancoCriptografada = (0, crypto_util_1.encrypt)(senha_usuario);
        await db_1.pool.query(`INSERT INTO credenciais (idusuario, dominio_banco, porta_banco, nome_banco, nome_usuario, senha_usuario, tipo_banco)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (idusuario)
       DO UPDATE SET 
         dominio_banco = EXCLUDED.dominio_banco,
         porta_banco = EXCLUDED.porta_banco,
         nome_banco = EXCLUDED.nome_banco,
         nome_usuario = EXCLUDED.nome_usuario,
         senha_usuario = EXCLUDED.senha_usuario,
         tipo_banco = EXCLUDED.tipo_banco`, [idusuario, dominio_banco, porta_banco, nome_banco, nome_usuario, senhaBancoCriptografada, tipo_banco]);
        res.status(201).json({ mensagem: 'Credenciais cadastradas com sucesso.' });
    }
    catch (error) {
        console.error('Erro ao cadastrar credenciais:', error);
        res.status(500).json({ mensagem: 'Erro interno ao cadastrar as credenciais.' });
    }
};
exports.criar = criar;
// ✅ NOVO MÉTODO PUT PARA ATUALIZAR VANNA.AI
const atualizarVanna = async (req, res) => {
    const { idusuario } = req.params;
    const { api_key, model } = req.body;
    if (!api_key || !model) {
        res.status(400).json({ mensagem: 'API Key e Model são obrigatórios.' });
        return;
    }
    try {
        // Verificar se já existe registro
        const existingRecord = await db_1.pool.query('SELECT * FROM credenciais WHERE idusuario = $1', [idusuario]);
        let result;
        if (existingRecord.rows.length > 0) {
            // Atualizar registro existente
            result = await db_1.pool.query('UPDATE credenciais SET api_key = $1, model = $2 WHERE idusuario = $3 RETURNING *', [api_key, model, idusuario]);
        }
        else {
            // Inserir novo registro com valores padrão para campos obrigatórios
            result = await db_1.pool.query(`INSERT INTO credenciais (idusuario, api_key, model, dominio_banco, porta_banco, nome_banco, nome_usuario, senha_usuario, tipo_banco)
         VALUES ($1, $2, $3, '', 0, '', '', '', 'PostgreSQL') RETURNING *`, [idusuario, api_key, model]);
        }
        res.status(200).json({
            mensagem: 'Vanna.AI configurado com sucesso!',
            credenciais: result.rows[0]
        });
    }
    catch (error) {
        console.error('Erro ao atualizar Vanna.AI:', error);
        res.status(500).json({ mensagem: 'Erro interno ao configurar Vanna.AI.' });
    }
};
exports.atualizarVanna = atualizarVanna;
const buscarPorUsuario = async (req, res) => {
    const { idusuario } = req.params;
    try {
        const result = await db_1.pool.query('SELECT * FROM credenciais WHERE idusuario = $1', [idusuario]);
        if (result.rows.length === 0) {
            res.status(404).json({ mensagem: 'Credenciais não encontradas para este usuário.' });
            return;
        }
        const credenciais = result.rows[0];
        // Descriptografar a senha para retornar ao frontend
        let senhaDescriptografada = '';
        if (credenciais.senha_usuario) {
            try {
                senhaDescriptografada = (0, crypto_util_1.decrypt)(credenciais.senha_usuario);
            }
            catch (error) {
                console.error('Erro ao descriptografar senha:', error);
            }
        }
        // Retornar credenciais com senha descriptografada
        const credenciaisComSenha = {
            ...credenciais,
            senha_usuario: senhaDescriptografada
        };
        res.status(200).json(credenciaisComSenha);
    }
    catch (error) {
        console.error('Erro ao buscar credenciais:', error);
        res.status(500).json({ mensagem: 'Erro interno ao buscar as credenciais.' });
    }
};
exports.buscarPorUsuario = buscarPorUsuario;
// Nova função para obter credenciais descriptografadas (uso interno)
const obterCredenciaisDescriptografadas = async (idusuario) => {
    try {
        const result = await db_1.pool.query('SELECT * FROM credenciais WHERE idusuario = $1', [idusuario]);
        if (result.rows.length === 0) {
            return null;
        }
        return result.rows[0];
    }
    catch (error) {
        console.error('Erro ao buscar credenciais descriptografadas:', error);
        throw error;
    }
};
exports.obterCredenciaisDescriptografadas = obterCredenciaisDescriptografadas;
