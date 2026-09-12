"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const userCredentials_controller_1 = require("../controllers/userCredentials.controller");
const db_1 = require("../database/db");
const crypto = __importStar(require("../utils/crypto.util"));
jest.mock('../database/db');
jest.mock('../utils/crypto.util');
const mockPool = db_1.pool;
const mockCrypto = crypto;
// Configurar o mock do pool.query
mockPool.query = jest.fn();
describe('UserCredentials Controller', () => {
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
    describe('criar', () => {
        it('deve criar credenciais com sucesso', async () => {
            mockReq = {
                body: {
                    idusuario: 1,
                    dominio_banco: 'localhost',
                    porta_banco: 5432,
                    nome_banco: 'testdb',
                    nome_usuario: 'testuser',
                    senha_usuario: 'testpass',
                    tipo_banco: 'postgresql'
                }
            };
            mockCrypto.encrypt.mockReturnValue('encrypted-password');
            // Corrigindo o mock - aplicando cast de tipagem correto
            mockPool.query.mockResolvedValueOnce({ rows: [], rowCount: 0 });
            await (0, userCredentials_controller_1.criar)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(201);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Credenciais cadastradas com sucesso.'
            });
        });
        it('deve retornar erro quando campos obrigatórios estão faltando', async () => {
            mockReq = {
                body: {
                    idusuario: 1
                    // faltando outros campos
                }
            };
            await (0, userCredentials_controller_1.criar)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Todos os campos são obrigatórios.'
            });
        });
        it('deve retornar erro para tipo de banco inválido', async () => {
            mockReq = {
                body: {
                    idusuario: 1,
                    dominio_banco: 'localhost',
                    porta_banco: 5432,
                    nome_banco: 'testdb',
                    nome_usuario: 'testuser',
                    senha_usuario: 'testpass',
                    tipo_banco: 'oracle'
                }
            };
            await (0, userCredentials_controller_1.criar)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(400);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Tipo de banco deve ser PostgreSQL ou MySQL.'
            });
        });
    });
    describe('buscarPorUsuario', () => {
        it('deve buscar credenciais com sucesso', async () => {
            const mockCredentials = {
                idusuario: 1,
                dominio_banco: 'localhost',
                porta_banco: 5432,
                nome_banco: 'testdb',
                nome_usuario: 'testuser',
                senha_usuario: 'encrypted-password',
                tipo_banco: 'postgresql'
            };
            mockReq = {
                params: { idusuario: '1' }
            };
            mockPool.query.mockResolvedValueOnce({
                rowCount: 1,
                rows: [mockCredentials]
            });
            mockCrypto.decrypt.mockReturnValue('decrypted-password');
            await (0, userCredentials_controller_1.buscarPorUsuario)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                ...mockCredentials,
                senha_usuario: 'decrypted-password'
            });
        });
    });
});
