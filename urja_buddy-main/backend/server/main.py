from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np

app = FastAPI(title="URJA BUDDY Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PredictRequest(BaseModel):
    history_kwh: list[float]

class NILMRequest(BaseModel):
    appliances: dict[str, float]

@app.post("/predict")
def predict(req: PredictRequest):
    hist = np.array(req.history_kwh[-12:], dtype=float)
    next_kwh = float(hist.mean() * 1.02)
    estimated_amount = next_kwh * 6.1
    last = hist[-1] if len(hist) else next_kwh
    percent_change = float(((next_kwh - last) / max(last, 1e-6)) * 100)
    return {
        "next_month_kwh": round(next_kwh, 2),
        "estimated_amount": round(estimated_amount, 2),
        "percent_change": round(percent_change, 2),
    }

@app.post("/nilm")
def nilm(req: NILMRequest):
    total = sum(req.appliances.values()) or 1.0
    share = {k: round(v / total * 100, 2) for k, v in req.appliances.items()}
    return share
