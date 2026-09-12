import { Request, Response } from 'express';
import { updateUser } from '../controllers/updateUser.controller';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';
import { QueryResult } from 'pg';

// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');

// Tipagem correta dos mocks
const mockPool = pool as jest.Mocked<typeof pool>;
const mockBcrypt = bcrypt as jest.Mocked<typeof bcrypt>;

// Configurar o mock do pool.query
mockPool.query = jest.fn();
mockBcrypt.hash = jest.fn();

describe('UpdateUser Controller', () => {
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
          nome: "João Atualizado",
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
      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [currentUser],
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para atualização
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ idusuario: 1 }],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await updateUser(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledTimes(2);
      expect(mockPool.query).toHaveBeenNthCalledWith(1,
        'SELECT nome, sobrenome, telefone FROM usuarios WHERE idusuario = $1',
        ['1']
      );
      expect(mockPool.query).toHaveBeenNthCalledWith(2,
        expect.stringContaining('UPDATE usuarios'),
        ['João Atualizado', 'Silva Atualizado', '11888888888', '1']
      );
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
      (mockBcrypt.hash as jest.Mock).mockResolvedValue(hashedPassword);

      // Mock para buscar usuário atual
      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [currentUser],
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para atualização
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ idusuario: 1 }],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await updateUser(mockReq as Request, mockRes as Response);

      expect(mockBcrypt.hash).toHaveBeenCalledWith('novaSenha123', 10);
      expect(mockPool.query).toHaveBeenCalledTimes(2);
      expect(mockPool.query).toHaveBeenNthCalledWith(2,
        expect.stringContaining('UPDATE usuarios'),
        ['João', 'Silva', '11999999999', hashedPassword, '1']
      );
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

      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [currentUser],
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ idusuario: 1 }],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await updateUser(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenNthCalledWith(2,
        expect.stringContaining('UPDATE usuarios'),
        ['João Atualizado', 'Silva', '11999999999', '1'] // Mantém valores atuais
      );
    });

    it('deve manter nome atual quando não fornecido no body', async () => {
      mockReq = {
        params: { idusuario: '1' },
        body: {
          // Apenas sobrenome e telefone, sem nome
          sobrenome: 'Silva Atualizado',
          telefone: '11888888888'
        }
      };

      const currentUser = {
        nome: 'João Original',
        sobrenome: 'Silva',
        telefone: '11999999999'
      };

      // Mock para buscar usuário atual
      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [currentUser],
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para atualização
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ idusuario: 1 }],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await updateUser(mockReq as Request, mockRes as Response);

      // Verificar que o nome original foi mantido
      expect(mockPool.query).toHaveBeenNthCalledWith(2, 
        expect.stringContaining('UPDATE usuarios'),
        ['João Original', 'Silva Atualizado', '11888888888', '1']
      );

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        idusuario: 1,
        mensagem: 'Dados do usuário atualizados com sucesso.'
      });
    });

    it('deve retornar erro 400 quando nenhum campo é fornecido', async () => {
      mockReq = {
        params: { idusuario: '1' },
        body: {}
      };

      await updateUser(mockReq as Request, mockRes as Response);

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

      await updateUser(mockReq as Request, mockRes as Response);

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

      await updateUser(mockReq as Request, mockRes as Response);

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
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 0,
        rows: [],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await updateUser(mockReq as Request, mockRes as Response);

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
      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [currentUser],
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        .mockResolvedValueOnce({
          rowCount: 0,
          rows: [],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await updateUser(mockReq as Request, mockRes as Response);

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
      (mockPool.query as jest.Mock).mockRejectedValue(new Error('Database connection error'));

      await updateUser(mockReq as Request, mockRes as Response);

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

      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [currentUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      // Mock para erro na criptografia
      (mockBcrypt.hash as jest.Mock).mockRejectedValue(new Error('Bcrypt error'));

      await updateUser(mockReq as Request, mockRes as Response);

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

      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [currentUser],
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ idusuario: 1 }],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      (mockBcrypt.hash as jest.Mock).mockResolvedValue('hashedPassword');

      await updateUser(mockReq as Request, mockRes as Response);

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