"""Publication scope for platform-specific GameStream builds."""
import json
from pathlib import Path


def require_public_distribution(root=None, platform=None):
    root = Path(root) if root is not None else Path(__file__).resolve().parents[1]
    policy = root / 'distribution-policy.json'
    if not policy.exists():
        return
    data = json.loads(policy.read_text())
    if data.get('mode') == 'private-only':
        raise ValueError('Esta compilación es de uso privado: publicación pública desactivada. Usa los artefactos del repositorio privado.')
    if data.get('mode') == 'platform-specific':
        if data.get('platforms', {}).get(platform) != 'public-installers':
            raise ValueError('La IPA integrada con Moonlight requiere autorización para distribuir el código fuente correspondiente con licencia compatible. La publicación del instalador no autoriza por sí sola a divulgar el código privado.')
