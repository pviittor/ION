"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const dotenv_1 = __importDefault(require("dotenv"));
const auth_routes_1 = __importDefault(require("./routes/auth.routes"));
const userCredentials_controller_1 = require("./controllers/userCredentials.controller");
// Configurar dotenv
dotenv_1.default.config();
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
// Usar _ para parâmetros não utilizados
app.use((req, _res, next) => {
    console.log(`ROTA: ${req.method} ${req.url}`);
    console.log('BODY:', req.body);
    next();
});
// Usar _ para parâmetros não utilizados
app.get('/', (_req, res) => {
    res.send('Hello World!');
});
app.use('/api', auth_routes_1.default);
app.use('/api', userCredentials_controller_1.criar);
app.use('/api', userCredentials_controller_1.buscarPorUsuario);
exports.default = app;
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});
