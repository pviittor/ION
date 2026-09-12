"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.login = void 0;
const db_1 = require("../database/db");
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const login = async (req, res) => {
    const { email, senha } = req.body;
    try {
        const result = await db_1.pool.query('SELECT * FROM usuarios WHERE email = $1', [email]);
        if (result.rowCount === 0) {
            res.status(400).json({ mensagem: 'Usuário não encontrado' });
            return;
        }
        const usuario = result.rows[0];
        const senhaCorreta = await bcrypt_1.default.compare(senha, usuario.senha);
        if (!senhaCorreta) {
            res.status(401).json({ mensagem: 'Senha incorreta' });
            return;
        }
        const token = jsonwebtoken_1.default.sign({ id: usuario.idusuario, email: usuario.email }, process.env.JWT_SECRET, { expiresIn: '1d' });
        res.status(200).json({
            mensagem: 'Login realizado com sucesso',
            token,
            usuario: {
                id: usuario.idusuario,
                nome: usuario.nome,
                email: usuario.email,
            },
        });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ mensagem: 'Erro interno do servidor' });
    }
};
exports.login = login;
