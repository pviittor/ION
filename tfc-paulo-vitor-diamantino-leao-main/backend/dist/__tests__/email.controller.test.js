"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const db_1 = require("../database/db");
const bcrypt_1 = __importDefault(require("bcrypt"));
const moment_1 = __importDefault(require("moment"));
require("moment-timezone");
// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');
// Mock do nodemailer ANTES da importação do controller
const mockSendMail = jest.fn();
const mockTransporter = {
    sendMail: mockSendMail
};
jest.mock('nodemailer', () => ({
    createTransport: jest.fn(() => mockTransporter)
}));
// Agora importar o controller DEPOIS dos mocks
const email_controller_1 = require("../controllers/email.controller");
// Mock do moment
const mockMomentInstance = {
    add: jest.fn().mockReturnThis(),
    isAfter: jest.fn(() => false),
    toDate: jest.fn(() => new Date('2024-01-01T16:00:00.000Z')),
    tz: jest.fn().mockReturnThis()
};
// Garantir que todos os métodos retornem o próprio instance para chaining
mockMomentInstance.add.mockReturnValue(mockMomentInstance);
mockMomentInstance.tz.mockReturnValue(mockMomentInstance);
// Mock do moment
jest.mock('moment', () => {
    const mockMoment = jest.fn(() => mockMomentInstance);
    mockMoment.tz = jest.fn(() => mockMomentInstance);
    return mockMoment;
});
// Mock do moment-timezone separadamente
jest.mock('moment-timezone', () => {
    const mockMoment = jest.fn(() => mockMomentInstance);
    mockMoment.tz = jest.fn(() => mockMomentInstance);
    return mockMoment;
});
// Tipagem correta dos mocks
const mockPool = db_1.pool;
const mockBcrypt = bcrypt_1.default;
// Configurar o mock do pool.query
mockPool.query = jest.fn();
describe('Email Controller', () => {
    let mockReq;
    let mockRes;
    let mockStatus;
    let mockJson;
    beforeEach(() => {
        mockJson = jest.fn();
        mockStatus = jest.fn().mockReturnValue({ json: mockJson });
        mockRes = {
            status: mockStatus,
            json: mockJson
        };
        jest.clearAllMocks();
    });
    describe('sendPasswordResetEmail', () => {
        it('deve enviar email de redefinição com sucesso', async () => {
            mockReq = {
                body: {
                    email: 'test@example.com'
                }
            };
            // Mock para encontrar usuário
            mockPool.query
                .mockResolvedValueOnce({
                rows: [{ idusuario: 1, nome: 'João' }],
                rowCount: 1,
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                // Mock para deletar tokens antigos
                .mockResolvedValueOnce({
                rowCount: 0,
                rows: [],
                command: 'DELETE',
                oid: 0,
                fields: []
            })
                // Mock para inserir novo token
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [{ id: 1 }],
                command: 'INSERT',
                oid: 0,
                fields: []
            });
            mockSendMail.mockResolvedValue({ messageId: 'test-id' });
            await (0, email_controller_1.sendPasswordResetEmail)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledTimes(3);
            expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
                from: process.env.EMAIL_USER,
                to: 'test@example.com',
                subject: 'Ion - Redefinição de Senha',
                html: expect.stringContaining('João')
            }));
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                message: 'Email de redefinição enviado com sucesso',
                tokenPreview: expect.any(String)
            });
        });
        it('deve retornar erro quando email não é fornecido', async () => {
            mockReq = {
                body: {}
            };
            await (0, email_controller_1.sendPasswordResetEmail)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Email é obrigatório'
            });
        });
        it('deve retornar erro quando email não está cadastrado', async () => {
            mockReq = {
                body: {
                    email: 'notfound@example.com'
                }
            };
            mockPool.query.mockResolvedValueOnce({
                rows: [],
                rowCount: 0,
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            await (0, email_controller_1.sendPasswordResetEmail)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(404);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Email não cadastrado'
            });
        });
        it('deve retornar erro interno quando ocorre exceção', async () => {
            mockReq = {
                body: {
                    email: 'test@example.com'
                }
            };
            mockPool.query.mockRejectedValue(new Error('Database error'));
            await (0, email_controller_1.sendPasswordResetEmail)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Erro interno do servidor'
            });
        });
    });
    describe('verifyResetToken', () => {
        it('deve verificar token válido com sucesso', async () => {
            mockReq = {
                body: {
                    token: '123456'
                }
            };
            mockPool.query.mockResolvedValueOnce({
                rows: [{
                        id: 1,
                        token: '123456',
                        token_expiracao: '2024-01-01T16:00:00.000Z', // 13:00 em São Paulo = 16:00 UTC
                        idusuario: 1,
                        email: 'test@example.com',
                        status: 'ativo',
                        tentativas_uso: 0
                    }],
                rowCount: 1,
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                // Mock para incrementar tentativas
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            await (0, email_controller_1.verifyResetToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                message: 'Codigo válido',
                idusuario: 1,
                email: 'test@example.com'
            });
        });
        it('deve retornar erro quando token não é fornecido', async () => {
            mockReq = {
                body: {}
            };
            await (0, email_controller_1.verifyResetToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Codigo é obrigatório'
            });
        });
        it('deve retornar erro quando token é inválido', async () => {
            mockReq = {
                body: {
                    token: 'invalid'
                }
            };
            mockPool.query.mockResolvedValueOnce({
                rows: [],
                rowCount: 0,
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            await (0, email_controller_1.verifyResetToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Código Inválido'
            });
        });
        it('deve retornar erro quando token está expirado', async () => {
            mockReq = {
                body: {
                    token: '123456'
                }
            };
            // Mock para token expirado - configurar isAfter para retornar true
            mockMomentInstance.isAfter.mockReturnValueOnce(true);
            mockPool.query.mockResolvedValueOnce({
                rows: [{
                        id: 1,
                        token: '123456',
                        token_expiracao: '2024-01-01T14:00:00.000Z', // 11:00 em São Paulo = 14:00 UTC
                        idusuario: 1,
                        email: 'test@example.com',
                        status: 'ativo',
                        tentativas_uso: 0
                    }],
                rowCount: 1,
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                // Mock para atualizar status para expirado
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            await (0, email_controller_1.verifyResetToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Codigo expirado'
            });
        });
    });
    describe('resetPasswordWithToken', () => {
        it('deve redefinir senha com sucesso', async () => {
            mockReq = {
                body: {
                    token: '123456',
                    newPassword: 'newpass123',
                    confirmPassword: 'newpass123'
                }
            };
            // Reset mock para token válido (não expirado)
            const mockMomentInstance = {
                isAfter: jest.fn(() => false)
            };
            moment_1.default.tz = jest.fn(() => mockMomentInstance);
            mockPool.query.mockResolvedValueOnce({
                rows: [{
                        id: 1,
                        token: '123456',
                        token_expiracao: '2024-01-01T16:00:00.000Z', // 13:00 em São Paulo = 16:00 UTC
                        idusuario: 1,
                        status: 'ativo'
                    }],
                rowCount: 1,
                command: 'SELECT',
                oid: 0,
                fields: []
            })
                // Mock para atualizar senha
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [],
                command: 'UPDATE',
                oid: 0,
                fields: []
            })
                // Mock para marcar token como usado
                .mockResolvedValueOnce({
                rowCount: 1,
                rows: [],
                command: 'UPDATE',
                oid: 0,
                fields: []
            });
            mockBcrypt.hash.mockResolvedValue('hashedpassword123');
            await (0, email_controller_1.resetPasswordWithToken)(mockReq, mockRes);
            expect(mockBcrypt.hash).toHaveBeenCalledWith('newpass123', 10);
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                message: 'Senha redefinida com sucesso'
            });
        });
        it('deve retornar erro quando campos obrigatórios não são fornecidos', async () => {
            mockReq = {
                body: {
                    token: '123456'
                    // newPassword e confirmPassword ausentes
                }
            };
            await (0, email_controller_1.resetPasswordWithToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Todos os campos são obrigatórios'
            });
        });
        it('deve retornar erro quando senhas não coincidem', async () => {
            mockReq = {
                body: {
                    token: '123456',
                    newPassword: 'newpass123',
                    confirmPassword: 'differentpass'
                }
            };
            await (0, email_controller_1.resetPasswordWithToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'As senhas não coincidem'
            });
        });
        it('deve retornar erro quando token não é encontrado', async () => {
            mockReq = {
                body: {
                    token: 'invalid',
                    newPassword: 'newpass123',
                    confirmPassword: 'newpass123'
                }
            };
            mockPool.query.mockResolvedValueOnce({
                rows: [],
                rowCount: 0,
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            await (0, email_controller_1.resetPasswordWithToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Codigo não encontrado ou inválido'
            });
        });
        it('deve retornar erro interno quando ocorre exceção', async () => {
            mockReq = {
                body: {
                    token: '123456',
                    newPassword: 'newpass123',
                    confirmPassword: 'newpass123'
                }
            };
            // Reset mock para não expirado antes do erro
            const mockMomentInstance = {
                isAfter: jest.fn(() => false)
            };
            moment_1.default.tz = jest.fn(() => mockMomentInstance);
            mockPool.query.mockRejectedValue(new Error('Database error'));
            await (0, email_controller_1.resetPasswordWithToken)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                error: 'Erro interno do servidor'
            });
        });
    });
});
