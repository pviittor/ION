import { Request, Response } from 'express';
import { criar, buscarPorUsuario, atualizarVanna, obterCredenciaisDescriptografadas } from '../controllers/userCredentials.controller';
import { pool } from '../database/db';
import * as crypto from '../utils/crypto.util';

jest.mock('../database/db');
jest.mock('../utils/crypto.util');

const mockPool = pool as jest.Mocked<typeof pool>;
const mockCrypto = crypto as jest.Mocked<typeof crypto>;

// Configurar o mock do pool.query
mockPool.query = jest.fn() as jest.MockedFunction<any>;

describe('UserCredentials Controller', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockJson: jest.Mock;
  let mockStatus: jest.Mock;

  beforeEach(() => {
    mockJson = jest.fn();
    mockStatus = jest.fn().mockReturnValue({ json: mockJson });
    mockRes = {
      status: mockStatus,
      json: mockJson
    };
    jest.clearAllMocks();
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
      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({ rows: [], rowCount: 0 });

      await criar(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(201);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Credenciais cadastradas com sucesso.'
      });
    });

    it('deve retornar erro quando campos obrigatórios estão faltando', async () => {
      mockReq = {
        body: {
          idusuario: 1
        }
      };

      await criar(mockReq as Request, mockRes as Response);

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

      await criar(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Tipo de banco deve ser PostgreSQL ou MySQL.'
      });
    });

    it('deve lidar com erro do banco de dados ao criar credenciais', async () => {
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
      (mockPool.query as jest.MockedFunction<any>).mockRejectedValueOnce(new Error('Erro de banco de dados'));

      await criar(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno ao cadastrar as credenciais.'
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

      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rowCount: 1,
        rows: [mockCredentials]
      });

      mockCrypto.decrypt.mockReturnValue('decrypted-password');

      await buscarPorUsuario(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        ...mockCredentials,
        senha_usuario: 'decrypted-password'
      });
    });

    it('deve retornar 404 quando credenciais não são encontradas', async () => {
      mockReq = {
        params: { idusuario: '1' }
      };

      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rowCount: 0,
        rows: []
      });

      await buscarPorUsuario(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(404);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Credenciais não encontradas para este usuário.'
      });
    });

    it('deve lidar com erro de descriptografia', async () => {
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

      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rowCount: 1,
        rows: [mockCredentials]
      });

      mockCrypto.decrypt.mockImplementation(() => {
        throw new Error('Erro de descriptografia');
      });

      await buscarPorUsuario(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        ...mockCredentials,
        senha_usuario: ''
      });
    });

    it('deve lidar com erro do banco de dados ao buscar', async () => {
      mockReq = {
        params: { idusuario: '1' }
      };

      (mockPool.query as jest.MockedFunction<any>).mockRejectedValueOnce(new Error('Erro de banco de dados'));

      await buscarPorUsuario(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno ao buscar as credenciais.'
      });
    });
  });

  describe('atualizarVanna', () => {
    it('deve atualizar configuração do Vanna.AI com sucesso para usuário existente', async () => {
      mockReq = {
        params: { idusuario: '1' },
        body: {
          api_key: 'test-api-key',
          model: 'test-model'
        }
      };

      (mockPool.query as jest.MockedFunction<any>)
        .mockResolvedValueOnce({ rows: [{ id: 1 }] }) // Verifica existência
        .mockResolvedValueOnce({ rows: [{ id: 1, api_key: 'test-api-key', model: 'test-model' }] }); // Atualização

      await atualizarVanna(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Vanna.AI configurado com sucesso!',
        credenciais: expect.objectContaining({
          api_key: 'test-api-key',
          model: 'test-model'
        })
      });
    });

    it('deve criar nova configuração do Vanna.AI para novo usuário', async () => {
      mockReq = {
        params: { idusuario: '1' },
        body: {
          api_key: 'test-api-key',
          model: 'test-model'
        }
      };

      (mockPool.query as jest.MockedFunction<any>)
        .mockResolvedValueOnce({ rows: [] }) // Usuário não existe
        .mockResolvedValueOnce({ rows: [{ id: 1, api_key: 'test-api-key', model: 'test-model' }] }); // Inserção

      await atualizarVanna(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Vanna.AI configurado com sucesso!',
        credenciais: expect.objectContaining({
          api_key: 'test-api-key',
          model: 'test-model'
        })
      });
    });

    it('deve retornar erro quando campos obrigatórios estão faltando', async () => {
      mockReq = {
        params: { idusuario: '1' },
        body: {
          api_key: 'test-api-key'
          // model faltando
        }
      };

      await atualizarVanna(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'API Key e Model são obrigatórios.'
      });
    });

    it('deve lidar com erro do banco de dados ao atualizar Vanna.AI', async () => {
      mockReq = {
        params: { idusuario: '1' },
        body: {
          api_key: 'test-api-key',
          model: 'test-model'
        }
      };

      (mockPool.query as jest.MockedFunction<any>).mockRejectedValueOnce(new Error('Erro de banco de dados'));

      await atualizarVanna(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno ao configurar Vanna.AI.'
      });
    });
  });

  describe('obterCredenciaisDescriptografadas', () => {
    it('deve retornar credenciais descriptografadas com sucesso', async () => {
      const mockCredentials = {
        idusuario: '1',
        dominio_banco: 'localhost',
        senha_usuario: 'encrypted-password'
      };

      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rows: [mockCredentials]
      });

      const result = await obterCredenciaisDescriptografadas('1');

      expect(result).toEqual(mockCredentials);
    });

    it('deve retornar null quando credenciais não são encontradas', async () => {
      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rows: []
      });

      const result = await obterCredenciaisDescriptografadas('1');

      expect(result).toBeNull();
    });

    it('deve propagar erro do banco de dados', async () => {
      const dbError = new Error('Erro de banco de dados');
      (mockPool.query as jest.MockedFunction<any>).mockRejectedValueOnce(dbError);

      await expect(obterCredenciaisDescriptografadas('1')).rejects.toThrow(dbError);
    });
  });
});