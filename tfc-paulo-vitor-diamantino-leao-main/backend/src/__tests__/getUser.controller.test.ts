import { Request, Response } from 'express';
import { getUser, getUserByPhone } from '../controllers/getUser.controller';
import { pool } from '../database/db';
import { QueryResult } from 'pg';

// Mock dos módulos
jest.mock('../database/db');

// Tipagem correta dos mocks
const mockPool = pool as jest.Mocked<typeof pool>;

// Configurar o mock do pool.query
mockPool.query = jest.fn();

describe('GetUser Controller', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockJson: jest.Mock;
  let mockStatus: jest.Mock;
  let consoleSpy: jest.SpyInstance;

  beforeEach(() => {
    mockJson = jest.fn();
    mockStatus = jest.fn().mockReturnValue({ json: mockJson });
    mockRes = {
      status: mockStatus,
      json: mockJson
    };
    consoleSpy = jest.spyOn(console, 'error').mockImplementation();
    // Limpar mocks anteriores
    jest.clearAllMocks();
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  describe('getUser', () => {
    it('deve retornar usuário com sucesso quando encontrado', async () => {
      mockReq = {
        params: {
          idusuario: '1'
        }
      };

      const mockUser = {
        idusuario: 1,
        nome: 'João',
        sobrenome: 'Silva',
        telefone: '11999999999'
      };

      // Mock para usuário encontrado
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUser(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1',
        ['1']
      );
      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        usuario: {
          idusuario: 1,
          nome: 'João',
          sobrenome: 'Silva',
          telefone: '11999999999'
        }
      });
    });

    it('deve retornar erro 404 quando usuário não é encontrado', async () => {
      mockReq = {
        params: {
          idusuario: '999'
        }
      };

      // Mock para usuário não encontrado
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 0,
        rows: [],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUser(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1',
        ['999']
      );
      expect(mockStatus).toHaveBeenCalledWith(404);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Usuário não encontrado.'
      });
    });

    it('deve tratar erros do banco de dados', async () => {
      mockReq = {
        params: {
          idusuario: '1'
        }
      };

      // Mock para erro do banco de dados
      (mockPool.query as jest.Mock).mockRejectedValue(new Error('Database connection error'));

      await getUser(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1',
        ['1']
      );
      expect(consoleSpy).toHaveBeenCalledWith('Erro ao recuperar dados do usuário:', expect.any(Error));
      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno do servidor.'
      });
    });
  });

  describe('getUserByPhone', () => {
    it('deve retornar usuário com sucesso quando encontrado por telefone', async () => {
      mockReq = {
        params: {
          telefone: '11999999999'
        }
      };

      const mockUser = {
        idusuario: 1,
        nome: 'João',
        sobrenome: 'Silva',
        telefone: '11999999999'
      };

      // Mock para usuário encontrado com QueryResult completo
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUserByPhone(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE telefone = $1',
        ['11999999999']
      );
      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        id: 1,
        idusuario: 1,
        nome: 'João',
        sobrenome: 'Silva',
        telefone: '11999999999'
      });
    });

    it('deve limpar número de telefone removendo caracteres especiais', async () => {
      mockReq = {
        params: {
          telefone: '(11) 99999-9999'
        }
      };

      const mockUser = {
        idusuario: 1,
        nome: 'João',
        sobrenome: 'Silva',
        telefone: '11999999999'
      };

      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUserByPhone(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE telefone = $1',
        ['11999999999']
      );
    });

    it('deve remover código do país (55) quando presente', async () => {
      mockReq = {
        params: {
          telefone: '5511999999999'
        }
      };

      const mockUser = {
        idusuario: 1,
        nome: 'João',
        sobrenome: 'Silva',
        telefone: '11999999999'
      };

      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUserByPhone(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE telefone = $1',
        ['11999999999']
      );
    });

    it('deve retornar erro 404 quando usuário não é encontrado por telefone', async () => {
      mockReq = {
        params: {
          telefone: '11888888888'
        }
      };

      // Mock para usuário não encontrado
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 0,
        rows: [],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUserByPhone(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE telefone = $1',
        ['11888888888']
      );
      expect(mockStatus).toHaveBeenCalledWith(404);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Usuário não encontrado com este telefone.'
      });
    });

    it('deve tratar erros do banco de dados na busca por telefone', async () => {
      mockReq = {
        params: {
          telefone: '11999999999'
        }
      };

      // Mock para erro do banco de dados
      (mockPool.query as jest.Mock).mockRejectedValue(new Error('Database connection error'));

      await getUserByPhone(mockReq as Request, mockRes as Response);

      expect(consoleSpy).toHaveBeenCalledWith('Erro ao recuperar dados do usuário por telefone:', expect.any(Error));
      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno do servidor.'
      });
    });

    it('deve manter número sem código do país quando não tem 13 dígitos', async () => {
      mockReq = {
        params: {
          telefone: '5511999999'
        }
      };

      const mockUser = {
        idusuario: 1,
        nome: 'João',
        sobrenome: 'Silva',
        telefone: '5511999999'
      };

      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await getUserByPhone(mockReq as Request, mockRes as Response);

      // Deve manter o número original pois não tem 13 dígitos
      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT idusuario, nome, sobrenome, telefone FROM usuarios WHERE telefone = $1',
        ['5511999999']
      );
    });
  });
});