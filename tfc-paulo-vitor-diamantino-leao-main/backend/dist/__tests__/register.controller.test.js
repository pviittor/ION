"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const register_controller_1 = require("../controllers/register.controller");
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
describe('Register Controller', () => {
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
    });
    describe('register', () => {
        it('deve cadastrar usuário com sucesso', async () => {
            mockReq = {
                body: {
                    nome: 'João',
                    sobrenome: 'Silva',
                    email: 'joao@test.com',
                    telefone: '11999999999',
                    senha: 'password123'
                }
            };
            // Mock para verificar se email já existe
            mockPool.query.mockResolvedValueOnce({
                rowCount: 0,
                rows: []
            });
            // Mock para inserir usuário
            mockPool.query.mockResolvedValueOnce({
                rows: [{ idusuario: 1 }]
            });
            mockBcrypt.hash.mockResolvedValue('hashedPassword');
            await (0, register_controller_1.register)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(201);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Usuário cadastrado com sucesso',
                idusuario: 1
            });
        });
        it('deve retornar erro quando campos obrigatórios estão faltando', async () => {
            mockReq = {
                body: {
                    nome: 'João',
                    // faltando outros campos
                }
            };
            await (0, register_controller_1.register)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Todos os campos são obrigatórios.'
            });
        });
        it('deve retornar erro quando email já está cadastrado', async () => {
            mockReq = {
                body: {
                    nome: 'João',
                    sobrenome: 'Silva',
                    email: 'joao@test.com',
                    telefone: '11999999999',
                    senha: 'password123'
                }
            };
            mockPool.query.mockResolvedValueOnce({
                rowCount: 1,
                rows: [{ email: 'joao@test.com' }]
            });
            await (0, register_controller_1.register)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Email já cadastrado.'
            });
        });
    });
});
