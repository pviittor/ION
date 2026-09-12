
// Mock do banco de dados
jest.mock('../database/db', () => ({
  pool: {
    query: jest.fn(),
    connect: jest.fn(),
    end: jest.fn()
  }
}));

// Mock do nodemailer
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => ({
    sendMail: jest.fn().mockResolvedValue({ messageId: 'test-message-id' })
  }))
}));

// Mock das variáveis de ambiente
process.env.JWT_SECRET = 'test-jwt-secret';
process.env.EMAIL_USER = 'test@gmail.com';
process.env.EMAIL_PASS = 'test-password';
process.env.ENCRYPTION_KEY = 'test-encryption-key-32-characters!';
process.env.DB_USER = 'test-user';
process.env.DB_HOST = 'localhost';
process.env.DB_NAME = 'test-db';
process.env.DB_PASSWORD = 'test-password';
process.env.DB_PORT = '5432';

// Suprimir console.log e console.warn durante os testes
const originalConsoleLog = console.log;
const originalConsoleWarn = console.warn;
const originalConsoleError = console.error;

beforeAll(() => {
  // Suprimir logs mas manter um mock para console.error nos testes
  console.log = jest.fn();
  console.warn = jest.fn();
  console.error = jest.fn();
});

afterAll(() => {
  // Restaurar console original
  console.log = originalConsoleLog;
  console.warn = originalConsoleWarn;
  console.error = originalConsoleError;
});

// Setup global para testes
beforeEach(() => {
  jest.clearAllMocks();
});
