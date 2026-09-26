"""Thin wrapper around the Riot Games REST API (Account-V1, Match-V5, League-V4, Summoner-V4).

Handles two host types:
  * platform hosts (na1, euw1, kr, ...) -> League-V4, Summoner-V4
  * regional hosts (americas, europe, asia, sea) -> Account-V1, Match-V5

Rate limiting: on HTTP 429, sleeps and retries by default. Pass
``raise_on_rate_limit=True`` to instead raise :class:`RateLimitError` so a
caller (e.g. seed_matches' region interleaver) can switch to other work.
"""

from __future__ import annotations

import time
from typing import Any

import requests

from .config import RiotConfig, load_riot_config

# Regional routing value for each platform routing value.
# https://developer.riotgames.com/apis#account-v1
PLATFORM_TO_REGION: dict[str, str] = {
    "na1": "americas",
    "br1": "americas",
    "la1": "americas",
    "la2": "americas",
    "euw1": "europe",
    "eun1": "europe",
    "tr1": "europe",
    "ru": "europe",
    "kr": "asia",
    "jp1": "asia",
    "oc1": "sea",
    "ph2": "sea",
    "sg2": "sea",
    "th2": "sea",
    "tw2": "sea",
    "vn2": "sea",
}


class RiotAPIError(Exception):
    """Non-429 HTTP error from the Riot API."""

    def __init__(self, status_code: int, message: str, url: str):
        super().__init__(f"HTTP {status_code} for {url}: {message}")
        self.status_code = status_code
        self.url = url


class RateLimitError(Exception):
    """Raised on HTTP 429 when the client is constructed with raise_on_rate_limit=True."""

    def __init__(self, retry_after: float):
        super().__init__(f"Rate limited, retry after {retry_after:.0f}s")
        self.retry_after = retry_after


class RiotClient:
    def __init__(
        self,
        config: RiotConfig | None = None,
        *,
        raise_on_rate_limit: bool = False,
        max_retries: int = 3,
        timeout: float = 15.0,
    ):
        self.config = config or load_riot_config()
        self.raise_on_rate_limit = raise_on_rate_limit
        self.max_retries = max_retries
        self.timeout = timeout
        self._session = requests.Session()
        self._session.headers.update({"X-Riot-Token": self.config.api_key})

    # ------------------------------------------------------------- core HTTP

    def _get(self, host: str, path: str, *, params: dict[str, Any] | None = None) -> Any:
        url = f"https://{host}.api.riotgames.com{path}"
        attempt = 0
        while True:
            resp = self._session.get(url, params=params, timeout=self.timeout)
            if resp.status_code == 429:
                retry_after = float(resp.headers.get("Retry-After", "1"))
                if self.raise_on_rate_limit:
                    raise RateLimitError(retry_after)
                attempt += 1
                if attempt > self.max_retries:
                    raise RiotAPIError(429, "rate limited, retries exhausted", url)
                time.sleep(retry_after)
                continue
            if resp.status_code >= 400:
                raise RiotAPIError(resp.status_code, resp.text[:500], url)
            return resp.json()

    def _get_region(self, path: str, *, params: dict[str, Any] | None = None) -> Any:
        return self._get(self.config.region, path, params=params)

    def _get_platform(self, path: str, *, params: dict[str, Any] | None = None) -> Any:
        return self._get(self.config.platform, path, params=params)

    # ---------------------------------------------------------- Account-V1

    def get_account_by_riot_id(self, game_name: str, tag_line: str) -> dict[str, Any]:
        path = f"/riot/account/v1/accounts/by-riot-id/{game_name}/{tag_line}"
        return self._get_region(path)

    # ------------------------------------------------------------ Match-V5

    def get_match_ids_by_puuid(
        self,
        puuid: str,
        *,
        start: int = 0,
        count: int = 20,
        queue: int | None = None,
        match_type: str | None = None,
    ) -> list[str]:
        params: dict[str, Any] = {"start": start, "count": count}
        if queue is not None:
            params["queue"] = queue
        if match_type is not None:
            params["type"] = match_type
        path = f"/lol/match/v5/matches/by-puuid/{puuid}/ids"
        return self._get_region(path, params=params)

    def get_match(self, match_id: str) -> dict[str, Any]:
        return self._get_region(f"/lol/match/v5/matches/{match_id}")

    def get_match_timeline(self, match_id: str) -> dict[str, Any]:
        return self._get_region(f"/lol/match/v5/matches/{match_id}/timeline")

    # ------------------------------------------------------------ League-V4

    def get_league_entries(
        self, tier: str, division: str, *, queue: str = "RANKED_SOLO_5x5", page: int = 1
    ) -> list[dict[str, Any]]:
        path = f"/lol/league/v4/entries/{queue}/{tier}/{division}"
        return self._get_platform(path, params={"page": page})

    def get_apex_league(self, tier: str, *, queue: str = "RANKED_SOLO_5x5") -> dict[str, Any]:
        endpoint = {
            "MASTER": "masterleagues",
            "GRANDMASTER": "grandmasterleagues",
            "CHALLENGER": "challengerleagues",
        }[tier]
        return self._get_platform(f"/lol/league/v4/{endpoint}/by-queue/{queue}")

    # ---------------------------------------------------------- Summoner-V4

    def get_summoner_by_id(self, summoner_id: str) -> dict[str, Any]:
        return self._get_platform(f"/lol/summoner/v4/summoners/{summoner_id}")
