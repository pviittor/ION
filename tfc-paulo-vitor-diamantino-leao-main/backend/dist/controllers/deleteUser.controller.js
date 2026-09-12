"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUser = void 0;
const db_1 = require("../database/db");
const deleteUser = async (req, res) => {
    const { idusuario } = req.params; // ID do usuário a ser excluído
    try {
        const result = await db_1.pool.query('DELETE FROM usuarios WHERE idusuario = $1 RETURNING idusuario', [idusuario]);
        if (result.rowCount === 0) {
            res.status(404).json({ mensagem: 'Usuário não encontrado.' });
            return;
        }
        res.status(200).json({ mensagem: 'Conta excluída com sucesso!' });
    }
    catch (error) {
        console.error('Erro ao excluir conta:', error);
        res.status(500).json({ mensagem: 'Erro interno do servidor.' });
    }
};
exports.deleteUser = deleteUser;
