"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const updateUser_controller_1 = require("../controllers/updateUser.controller");
const db_1 = require("../database/db");
const bcrypt_1 = __importDefault(require("bcrypt"));
// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');
// Tipagem correta dos mocks
const mockPool = db_1.pool;
const mockBcrypt = bcrypt_1.default;
// Configurar o mock do pool.query
mockPool.query = jest.fn();
mockBcrypt.hash = jest.fn();
describe('UpdateUser Controller', () => {
    let mockReq;
    let mockRes;
    let mockJson;
    let mockStatus;
    let consoleSpy;
    beforeEach(() => {
        mockJson = jest.fn();
        mockStatus = jest.fn().mockReturnValue({ json: mockJson });
        mockRes = {
            status: mockStatus,
            json: mockJson
        };
        consoleSpy = jest.spyOn(console, 'log').mockImplementation();
        jest.spyOn(console, 'error').mockImplementation();
        // Limpar mocks anteriores
        jest.clearAllMocks();
    });
    afterEach(() => {
        consoleSpy.mockRestore();
    });
    describe('updateUser', () => {
        it('deve atualizar usuário com sucesso sem alterar senha', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João Atualizado',
                    sobrenome: 'Silva Atualizado',
                    telefone: '11888888888'
                }
            };
            const currentUser = {
                nome: 'João',
                sobrenome: 'Silva',
                telefone: '11999999999'
            };
            // Mock para buscar usuário atual
            mockPool.query
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [currentUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                // Mock para atualização
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [{ idusuario: 1 }],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledTimes(2);
            expect(mockPool.query).toHaveBeenNthCalledWith(1, 'SELECT nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1', ['1']);
            expect(mockPool.query).toHaveBeenNthCalledWith(2, expect.stringContaining('UPDATE usuarios'), ['João Atualizado', 'Silva Atualizado', '11888888888', '1']);
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Dados do usuário atualizados com sucesso.',
                idusuario: 1
            });
        });
        it('deve atualizar usuário com sucesso incluindo senha', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João',
                    sobrenome: 'Silva',
                    telefone: '11999999999',
                    senha: 'novaSenha123',
                    confirmarSenha: 'novaSenha123'
                }
            };
            const currentUser = {
                nome: 'João',
                sobrenome: 'Silva',
                telefone: '11999999999'
            };
            const hashedPassword = 'hashedPassword123';
            mockBcrypt.hash.mockResolvedValue(hashedPassword);
            // Mock para buscar usuário atual
            mockPool.query
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [currentUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                // Mock para atualização
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [{ idusuario: 1 }],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockBcrypt.hash).toHaveBeenCalledWith('novaSenha123', 10);
            expect(mockPool.query).toHaveBeenCalledTimes(2);
            expect(mockPool.query).toHaveBeenNthCalledWith(2, expect.stringContaining('UPDATE usuarios'), ['João', 'Silva', '11999999999', hashedPassword, '1']);
            expect(mockStatus).toHaveBeenCalledWith(200);
        });
        it('deve manter valores atuais quando campos não são fornecidos', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João Atualizado'
                    // sobrenome e telefone não fornecidos
                }
            };
            const currentUser = {
                nome: 'João',
                sobrenome: 'Silva',
                telefone: '11999999999'
            };
            mockPool.query
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [currentUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [{ idusuario: 1 }],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenNthCalledWith(2, expect.stringContaining('UPDATE usuarios'), ['João Atualizado', 'Silva', '11999999999', '1'] // Mantém valores atuais
            );
        });
        it('deve retornar erro 400 quando nenhum campo é fornecido', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {}
            };
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Pelo menos um campo deve ser fornecido para atualização.'
            });
            expect(mockPool.query).not.toHaveBeenCalled();
        });
        it('deve retornar erro 400 quando senha é fornecida sem confirmação', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    senha: 'novaSenha123'
                    // confirmarSenha não fornecida
                }
            };
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Confirmação de senha é obrigatória ao alterar a senha.'
            });
            expect(mockPool.query).not.toHaveBeenCalled();
        });
        it('deve retornar erro 400 quando senhas não coincidem', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    senha: 'novaSenha123',
                    confirmarSenha: 'senhasDiferentes'
                }
            };
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'As senhas não coincidem.'
            });
            expect(mockPool.query).not.toHaveBeenCalled();
        });
        it('deve retornar erro 404 quando usuário não é encontrado na busca inicial', async () => {
            mockReq = {
                params: { idusuario: '999' },
                body: {
                    nome: 'João'
                }
            };
            // Mock para usuário não encontrado na busca inicial
            mockPool.query.mockResolvedValue({
                rowCount: 0,
                rows: [],
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledTimes(1);
            expect(mockStatus).toHaveBeenCalledWith(404);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Usuário não encontrado.'
            });
        });
        it('deve retornar erro 404 quando usuário não é encontrado na atualização', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João'
                }
            };
            const currentUser = {
                nome: 'João',
                sobrenome: 'Silva',
                telefone: '11999999999'
            };
            // Mock para buscar usuário atual (sucesso) e atualização (falha)
            mockPool.query
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [currentUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                .mockResolvedValueOnce({
                rowCount: 0,
                rows: [],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledTimes(2);
            expect(mockStatus).toHaveBeenCalledWith(404);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Usuário não encontrado.'
            });
        });
        it('deve tratar erros do banco de dados', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João'
                }
            };
            // Mock para erro do banco de dados
            mockPool.query.mockRejectedValue(new Error('Database connection error'));
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Erro interno do servidor.'
            });
        });
        it('deve tratar erros na criptografia da senha', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João',
                    senha: 'novaSenha123',
                    confirmarSenha: 'novaSenha123'
                }
            };
            const currentUser = {
                nome: 'João',
                sobrenome: 'Silva',
                telefone: '11999999999'
            };
            mockPool.query.mockResolvedValue({
                rowCount: 1,
                rows: [currentUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            // Mock para erro na criptografia
            mockBcrypt.hash.mockRejectedValue(new Error('Bcrypt error'));
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Erro interno do servidor.'
            });
        });
        it('deve fazer log dos dados recebidos (mascarando senhas)', async () => {
            mockReq = {
                params: { idusuario: '1' },
                body: {
                    nome: 'João',
                    senha: 'novaSenha123',
                    confirmarSenha: 'novaSenha123'
                }
            };
            const currentUser = {
                nome: 'João',
                sobrenome: 'Silva',
                telefone: '11999999999'
            };
            mockPool.query
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [currentUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [{ idusuario: 1 }],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            mockBcrypt.hash.mockResolvedValue('hashedPassword');
            await (0, updateUser_controller_1.updateUser)(mockReq, mockRes);
            expect(consoleSpy).toHaveBeenCalledWith('Dados recebidos:', {
                nome: 'João',
                sobrenome: undefined,
                telefone: undefined,
                senha: '***',
                confirmarSenha: '***'
            });
        });
    });
});
