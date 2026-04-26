from fastapi import FastAPI
from models import RerouteInput
from reroute import reroute_shipment

app = FastAPI()

@app.post("/reroute")
def reroute(data: RerouteInput):
    return reroute_shipment(data)