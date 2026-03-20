"""ZAI API provider for glm-4.7 model.

Uses OpenAI-compatible API at https://api.z.ai/api/coding/paas/v4
"""
import json
import httpx
from typing import AsyncIterator, Optional
from .base import BaseProvider, ProviderConfig, StreamChunk


class ZAIConfig(ProviderConfig):
    """ZAI API configuration."""
    api_key: str
    base_url: str = "https://api.z.ai/api/coding/paas/v4"
    default_model: str = "glm-4.7"  # glm-4.7 model


class ZAIProvider(BaseProvider):
    """ZAI API provider for Zhipu AI models (glm-4.7)."""

    def __init__(self, config: ZAIConfig):
        self.config = config
        self.client = httpx.AsyncClient(
            base_url=config.base_url,
            headers={
                "Authorization": f"Bearer {config.api_key}",
                "Content-Type": "application/json"
            },
            timeout=config.timeout
        )

    async def chat(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> str:
        """Non-streaming chat completion."""
        response = await self.client.post(
            "/chat/completions",
            json={
                "model": model or self.config.default_model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "stream": False
            }
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]

    async def chat_stream(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> AsyncIterator[StreamChunk]:
        """Streaming chat completion.

        ZAI returns both 'reasoning_content' (thinking) and 'content' (response).
        """
        try:
            async with self.client.stream(
                "POST",
                "/chat/completions",
                json={
                    "model": model or self.config.default_model,
                    "messages": messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                    "stream": True
                }
            ) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    if not line or line.strip() == "":
                        continue
                    if line.startswith("data: "):
                        data_str = line[6:]
                        if data_str == "[DONE]":
                            break
                        try:
                            data = json.loads(data_str)
                            choices = data.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                # Handle reasoning_content (thinking)
                                reasoning = delta.get("reasoning_content", "")
                                if reasoning:
                                    yield StreamChunk(type="thinking", content=reasoning)
                                # Handle content (actual response)
                                content = delta.get("content", "")
                                if content:
                                    yield StreamChunk(type="text", content=content)
                        except json.JSONDecodeError:
                            continue
                yield StreamChunk(type="complete")
        except httpx.HTTPError as e:
            yield StreamChunk(type="error", content=str(e))

    async def is_available(self) -> bool:
        """Check if ZAI API is accessible."""
        try:
            # Simple test call
            response = await self.client.post(
                "/chat/completions",
                json={
                    "model": self.config.default_model,
                    "messages": [{"role": "user", "content": "Hi"}],
                    "max_tokens": 10
                },
                timeout=10.0
            )
            return response.status_code == 200
        except Exception:
            return False

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()
