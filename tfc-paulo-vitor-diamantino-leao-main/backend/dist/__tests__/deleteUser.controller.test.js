"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const deleteUser_controller_1 = require("../controllers/deleteUser.controller");
const db_1 = require("../database/db");
// Mock dos módulos
jest.mock('../database/db');
// Tipagem correta dos mocks
const mockPool = db_1.pool;
// Configurar o mock do pool.query
mockPool.query = jest.fn();
describe('DeleteUser Controller', () => {
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
    describe('deleteUser', () => {
        it('deve excluir usuário com sucesso', async () => {
            mockReq = {
                params: {
                    idusuario: '1'
                }
            };
            // Mock para exclusão bem-sucedida
            mockPool.query.mockResolvedValue({
                rowCount: 1,
                rows: [{ idusuario: 1 }],
                command: 'DELETE',
                oid: 0,
                fields: []
            });
            await (0, deleteUser_controller_1.deleteUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledWith('DELETE FROM usuarios WHERE idusuario = $1 RETURNING idusuario', ['1']);
            expect(mockStatus).toHaveBeenCalledWith(200);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Conta excluída com sucesso!'
            });
        });
        it('deve retornar erro quando usuário não é encontrado', async () => {
            mockReq = {
                params: {
                    idusuario: '999'
                }
            };
            // Mock para usuário não encontrado
            mockPool.query.mockResolvedValue({
                rowCount: 0,
                rows: [],
                command: 'DELETE',
                oid: 0,
                fields: []
            });
            await (0, deleteUser_controller_1.deleteUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledWith('DELETE FROM usuarios WHERE idusuario = $1 RETURNING idusuario', ['999']);
            expect(mockStatus).toHaveBeenCalledWith(404);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Usuário não encontrado.'
            });
            // Verifica que status 200 NÃO foi chamado (correção do bug)
            expect(mockStatus).not.toHaveBeenCalledWith(200);
        });
        it('deve tratar erros do banco de dados', async () => {
            mockReq = {
                params: {
                    idusuario: '1'
                }
            };
            // Mock para erro do banco de dados
            mockPool.query.mockRejectedValue(new Error('Database connection error'));
            await (0, deleteUser_controller_1.deleteUser)(mockReq, mockRes);
            expect(mockPool.query).toHaveBeenCalledWith('DELETE FROM usuarios WHERE idusuario = $1 RETURNING idusuario', ['1']);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Erro interno do servidor.'
            });
        });
        it('deve lidar com parâmetros inválidos', async () => {
            mockReq = {
                params: {
                    idusuario: 'invalid'
                }
            };
            // Mock para erro de parâmetro inválido
            mockPool.query.mockRejectedValue(new Error('invalid input syntax for type integer'));
            await (0, deleteUser_controller_1.deleteUser)(mockReq, mockRes);
            expect(mockStatus).toHaveBeenCalledWith(500);
            expect(mockJson).toHaveBeenCalledWith({
                mensagem: 'Erro interno do servidor.'
            });
        });
    });
});
