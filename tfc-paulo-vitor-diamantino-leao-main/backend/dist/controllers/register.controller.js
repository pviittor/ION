"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = void 0;
const db_1 = require("../database/db");
const bcrypt_1 = __importDefault(require("bcrypt"));
const register = async (req, res) => {
    const { nome, sobrenome, email, telefone, senha } = req.body;
    try {
        // Verifica se todos os campos foram preenchidos
        if (!nome || !sobrenome || !email || !telefone || !senha) {
            res.status(400).json({ mensagem: 'Todos os campos são obrigatórios.' });
            return;
        }
        // Verifica se já existe usuário com o mesmo email
        const existingUser = await db_1.pool.query('SELECT 1 FROM usuarios WHERE email = $1', [email]);
        if (existingUser.rowCount && existingUser.rowCount > 0) {
            res.status(400).json({ mensagem: 'Email já cadastrado.' });
            return;
        }
        // Criptografa a senha
        const senhaCriptografada = await bcrypt_1.default.hash(senha, 10);
        // Insere no banco de dados
        const result = await db_1.pool.query(`INSERT INTO usuarios (nome, sobrenome, email, telefone, senha)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING idusuario`, [nome, sobrenome, email, telefone, senhaCriptografada]);
        const novoUsuarioId = result.rows[0].idusuario;
        res.status(201).json({
            mensagem: 'Usuário cadastrado com sucesso',
            idusuario: novoUsuarioId
        });
    }
    catch (error) {
        console.error('Erro ao cadastrar usuário:', error);
        res.status(500).json({ mensagem: 'Erro interno do servidor.' });
    }
};
exports.register = register;
