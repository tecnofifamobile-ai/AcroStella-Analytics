"""Explicit publication boundary for private GameStream builds."""
import json
from pathlib import Path

def require_public_distribution(root=None):
    root = Path(root) if root is not None else Path(__file__).resolve().parents[1]
    policy = root / 'distribution-policy.json'
    if policy.exists() and json.loads(policy.read_text()).get('mode') == 'private-only':
        raise ValueError('Esta compilación es de uso privado: publicación pública desactivada. Usa los artefactos del repositorio privado.')
