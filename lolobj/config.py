"""Environment/config loading + shared data paths.

Reads RIOT_API_KEY from the environment, falling back to a ``.env`` file
in the project root (KEY=VALUE per line, no external dependency needed).
"""

from __future__ import annotations

import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "raw"

_ENV_FILE = PROJECT_ROOT / ".env"


def _load_dotenv(path: Path = _ENV_FILE) -> None:
    """Populate os.environ from a simple KEY=VALUE .env file, if present.

    Does not override variables already set in the real environment.
    """
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def ensure_data_dirs() -> None:
    for sub in ("matches", "timelines", "rank_meta"):
        (RAW_DIR / sub).mkdir(parents=True, exist_ok=True)


class RiotConfig:
    """Holds an API key plus a platform (na1, euw1, ...) and its regional route."""

    __slots__ = ("api_key", "platform", "region")

    def __init__(self, api_key: str, platform: str = "na1", region: str | None = None):
        from .riot_client import PLATFORM_TO_REGION  # local import: avoid cycle

        self.api_key = api_key
        self.platform = platform
        self.region = region or PLATFORM_TO_REGION.get(platform, "americas")


def load_riot_config(platform: str = "na1") -> RiotConfig:
    _load_dotenv()
    api_key = os.environ.get("RIOT_API_KEY")
    if not api_key:
        raise RuntimeError(
            "RIOT_API_KEY not set. Put it in a .env file at the project root "
            "(RIOT_API_KEY=RGAPI-...) or export it as an environment variable."
        )
    return RiotConfig(api_key=api_key, platform=platform)
