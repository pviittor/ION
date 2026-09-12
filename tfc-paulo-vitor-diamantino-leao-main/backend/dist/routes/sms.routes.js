"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const sms_controller_1 = require("../controllers/sms.controller");
const router = (0, express_1.Router)();
router.post('/send-code', sms_controller_1.sendSMSCode);
router.post('/verify-code', sms_controller_1.verifySMSCode);
exports.default = router;
