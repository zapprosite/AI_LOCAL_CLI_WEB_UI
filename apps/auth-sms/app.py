import os
import time
from typing import Optional

import phonenumbers
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse, RedirectResponse
from jose import jwt
from pydantic import BaseModel

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
JWT_AUD = os.getenv("JWT_AUDIENCE", "openwebui")
JWT_ISS = os.getenv("JWT_ISSUER", "auth-sms")
JWT_EXP = int(os.getenv("JWT_EXPIRES", "3600"))

# Demo OTP store (memory). In produção, use Redis/DB + provider (Twilio/WhatsApp/SMS)
OTP_STORE = {}

app = FastAPI(title="Auth SMS / JWT", version="1.0")

class OTPRequest(BaseModel):
    phone: str

class OTPVerify(BaseModel):
    phone: str
    code: str


def normalize_phone(phone: str) -> str:
    try:
        num = phonenumbers.parse(phone, "BR")  # ajuste default
        if not phonenumbers.is_valid_number(num):
            raise ValueError("invalid phone")
        return phonenumbers.format_number(num, phonenumbers.PhoneNumberFormat.E164)
    except Exception:
        raise HTTPException(status_code=400, detail="Telefone inválido")


@app.get("/")
def root():
    return HTMLResponse(
        """
        <html><body>
        <h3>Auth SMS</h3>
        <form method="post" action="/otp/request">
          <input name="phone" placeholder="+55..." />
          <button type="submit">Enviar OTP</button>
        </form>
        </body></html>
        """
    )

@app.post("/otp/request")
@app.post("/otp/request", response_class=JSONResponse)
def otp_request_form(phone: Optional[str] = None, payload: Optional[OTPRequest] = None):
    p = phone or (payload.phone if payload else None)
    if not p:
        raise HTTPException(status_code=400, detail="phone requerido")
    phone_norm = normalize_phone(p)
    # Gerar código simples (demo). Produção: provider externo
    code = str(int(time.time()))[-6:]
    OTP_STORE[phone_norm] = {"code": code, "ts": time.time()}
    # Em produção: enviar via provider. Aqui retornamos em claro (apenas para testes locais)
    return {"status": "sent", "phone": phone_norm, "code": code}

@app.post("/otp/verify")
def otp_verify(v: OTPVerify):
    phone_norm = normalize_phone(v.phone)
    entry = OTP_STORE.get(phone_norm)
    if not entry or entry["code"] != v.code or time.time() - entry["ts"] > 300:
        raise HTTPException(status_code=400, detail="OTP inválido ou expirado")
    # Emitir JWT (sub: phone)
    claims = {
        "sub": phone_norm,
        "aud": JWT_AUD,
        "iss": JWT_ISS,
        "iat": int(time.time()),
        "exp": int(time.time()) + JWT_EXP,
    }
    token = jwt.encode(claims, JWT_SECRET, algorithm="HS256")
    # Para simplificar, definimos cookie x-auth-phone; você pode usar Authorization: Bearer
    resp = JSONResponse({"token": token, "sub": phone_norm})
    resp.set_cookie("x-auth-phone", token, httponly=True, secure=False, samesite="Lax", max_age=JWT_EXP)
    return resp

@app.get("/signin")
def signin_redirect(token: str):
    # Ponto de extensão: integrar com OpenWebUI (setar cookie de sessão se suportado)
    # Por ora, apenas valida o token e redireciona para UI
    try:
        jwt.decode(token, JWT_SECRET, audience=JWT_AUD, issuer=JWT_ISS, algorithms=["HS256"])
    except Exception:
        raise HTTPException(status_code=401, detail="Token inválido")
    resp = RedirectResponse(url=os.getenv("OPENWEBUI_URL", "http://localhost:3000/"))
    resp.set_cookie("x-auth-phone", token, httponly=True, secure=False, samesite="Lax", max_age=JWT_EXP)
    return resp
