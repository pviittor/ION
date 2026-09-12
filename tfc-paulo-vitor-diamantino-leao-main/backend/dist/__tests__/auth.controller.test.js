"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const auth_controller_1 = require("../controllers/auth.controller");
const db_1 = require("../database/db");
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');
jest.mock('jsonwebtoken');
// Tipagem correta dos mocks
const mockPool = db_1.pool;
const mockBcrypt = bcrypt_1.default;
const mockJwt = jsonwebtoken_1.default;
// Configurar o mock do pool.query
mockPool.query = jest.fn();
describe('Auth Controller', () => {
    let mockReq;
    let mockRes;
    let mockJson;
    let mockStatus;
    beforeEach(() => {
        mockJson = jest.fn();
        mockStatus = jest.fn().mockReturnValue({ json: mockJson });
        mockRes = {
            status: mockStatus,
            json: mockJson
        };
        // Limpar mocks anteriores
        jest.clearAllMocks();
    });
    describe('login', () => {
        it('deve fazer login com sucesso', async () => {
            const mockUser = {
                idusuario: 1,
                email: 'test@test.com',
                senha: 'hashedPassword',
                nome: 'Test User'
            };
            mockReq = {
                body: {
                    email: 'test@test.com',
                    senha: 'password123'
                }
            };
            // Configurar mocks para login com sucesso
            mockPool.query.mockResolvedValue({
                rowCount: 1,
                rows: [mockUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            mockBcrypt.compare.mockResolvedValue(true);
            mockJwt.sign.mockReturnValue('mock-token');
            await (0, auth_controller_1.login)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Login realizado com sucesso',
                token: 'mock-token',
                usuario: {
                    id: 1,
                    nome: 'Test User',
                    email: 'test@test.com'
                }
            });
        });
        it('deve retornar erro quando usuário não existe', async () => {
            mockReq = {
                body: {
                    email: 'nonexistent@test.com',
                    senha: 'password123'
                }
            };
            // Configurar mock para usuário não encontrado
            mockPool.query.mockResolvedValue({
                rowCount: 0,
                rows: [],
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            await (0, auth_controller_1.login)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Usuário não encontrado'
            });
        });
        it('deve retornar erro quando senha está incorreta', async () => {
            const mockUser = {
                idusuario: 1,
                email: 'test@test.com',
                senha: 'hashedPassword',
                nome: 'Test User'
            };
            mockReq = {
                body: {
                    email: 'test@test.com',
                    senha: 'wrongpassword'
                }
            };
            // Configurar mocks para senha incorreta
            mockPool.query.mockResolvedValue({
                rowCount: 1,
                rows: [mockUser],
                command: 'SELECT',
                oid: 0,
                fields: []
            });
            mockBcrypt.compare.mockResolvedValue(false);
            await (0, auth_controller_1.login)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(401);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Senha incorreta'
            });
        });
        it('deve tratar erros do banco de dados', async () => {
            mockReq = {
                body: {
                    email: 'test@test.com',
                    senha: 'password123'
                }
            };
            // Configurar mock para erro do banco de dados
            mockPool.query.mockRejectedValue(new Error('Database error'));
            await (0, auth_controller_1.login)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Erro interno do servidor'
            });
        });
    });
});
