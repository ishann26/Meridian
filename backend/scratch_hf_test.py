import sys, os, json, requests
from dotenv import load_dotenv

sys.path.insert(0, '.')
sys.path.insert(0, 'agents/decision_agent')
load_dotenv('.env', override=True)

# Verify token is valid first
key = os.environ.get('HF_API_KEY', '')
r = requests.get('https://huggingface.co/api/whoami', headers={'Authorization': f'Bearer {key}'})
if r.status_code == 200:
    print('Token check: OK', r.json().get('name'))
else:
    print('Token check:', r.status_code, r.json())

# Now call Mistral
from agent import get_decision
result = get_decision({
    'delayRisk': 0.78,
    'routeOptions': [
        {'index': 0, 'nodes': ['PORT_A','PORT_B','PORT_D'], 'estimatedTime': 185, 'label': 'current'},
        {'index': 1, 'nodes': ['PORT_A','PORT_D'], 'estimatedTime': 120, 'label': 'direct'},
    ],
    'optimizedSolution': {'route': ['PORT_A','PORT_D'], 'totalDistance': 3089.5, 'totalTime': 120},
    'constraints': {}
})
print()
print('=== MISTRAL DECISION ===')
print(json.dumps(result, indent=2))
