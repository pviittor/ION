"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const supertest_1 = __importDefault(require("supertest"));
const app_1 = __importDefault(require("../app"));
describe('API Tests', () => {
    test('GET /health should return 200', async () => {
        const response = await (0, supertest_1.default)(app_1.default)
            .get('/health')
            .expect(200);
    });
});
describe('POST /api/whatsapp/send-message', () => {
    test('should send a message and return 200', async () => {
        const response = await (0, supertest_1.default)(app_1.default)
            .post('/api/whatsapp/send-message')
            .send({
            phoneNumber: '64992157619',
            message: 'Hello, world!',
        })
            .expect(200);
    });
});
