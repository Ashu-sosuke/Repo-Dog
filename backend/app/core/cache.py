import time
from typing import Dict, Any, Optional

class SimpleTTLCache:
    """Fast in-memory TTL Cache to eliminate redundant GitHub API & Supabase queries."""
    def __init__(self, default_ttl_seconds: int = 300):
        self._cache: Dict[str, Dict[str, Any]] = {}
        self.default_ttl = default_ttl_seconds

    def get(self, key: str) -> Optional[Any]:
        if key in self._cache:
            item = self._cache[key]
            if time.time() < item["expires_at"]:
                return item["value"]
            else:
                del self._cache[key]
        return None

    def set(self, key: str, value: Any, ttl_seconds: Optional[int] = None):
        ttl = ttl_seconds if ttl_seconds is not None else self.default_ttl
        self._cache[key] = {
            "value": value,
            "expires_at": time.time() + ttl
        }

    def invalidate(self, key_prefix: str = ""):
        if not key_prefix:
            self._cache.clear()
        else:
            keys_to_del = [k for k in self._cache if k.startswith(key_prefix)]
            for k in keys_to_del:
                if k in self._cache:
                    del self._cache[k]

cache = SimpleTTLCache(default_ttl_seconds=300) # 5-minute default cache
