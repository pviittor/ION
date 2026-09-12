"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.decrypt = exports.encrypt = void 0;
const crypto_1 = __importDefault(require("crypto"));
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'sua-chave-secreta-32-caracteres-aqui!';
const ALGORITHM = 'aes-256-cbc';
// Garantir que a chave tenha 32 bytes
const getKey = () => {
    return crypto_1.default.createHash('sha256').update(ENCRYPTION_KEY).digest();
};
const encrypt = (text) => {
    const iv = crypto_1.default.randomBytes(16);
    const cipher = crypto_1.default.createCipheriv(ALGORITHM, getKey(), iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return iv.toString('hex') + ':' + encrypted;
};
exports.encrypt = encrypt;
const decrypt = (encryptedText) => {
    const textParts = encryptedText.split(':');
    const iv = Buffer.from(textParts.shift(), 'hex');
    const encryptedData = textParts.join(':');
    const decipher = crypto_1.default.createDecipheriv(ALGORITHM, getKey(), iv);
    let decrypted = decipher.update(encryptedData, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
};
exports.decrypt = decrypt;
