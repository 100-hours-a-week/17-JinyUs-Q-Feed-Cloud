import asyncio
import time
import random
from fastapi import FastAPI, Request
from fastapi.responses import Response

app = FastAPI()

# ── 지연 프로파일 ─────────────────────────────────────────────
# 운영 환경 실측값으로 교체할 것 (현재는 보수적 추정값)
DELAYS = {
    "llm": random.choice([random.random(5, 21), random.random(10, 20), random.random(30, 50)]),
    "stt": random.random(0.3, 2),
    "tts": random.random(0.3, 3),
}


@app.get("/health")
async def health():
    return {"status": "ok"}


# ── vLLM Mock ─────────────────────────────────────────────────
# 실제 호출: {GPU_LLM_URL}/v1/chat/completions
# VLLMProvider._call_api() 참고
@app.post("/v1/chat/completions")
async def mock_vllm(request: Request):
    await asyncio.sleep(DELAYS["llm"])
    return {
        "id": "mock-vllm-001",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": "mock-vllm",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                # structured_outputs 사용 시 JSON 문자열로 반환됨
                # RubricEvaluationResult, RouterOutput 등 다양한 schema에 대응하는 범용 응답
                "content": (
                    '{"accuracy":4,"logic":3,"specificity":3,'
                    '"completeness":4,"delivery":4,'
                    '"decision":"follow_up","reasoning":"mock",'
                    '"question_text":"mock question","category":"OS",'
                    '"cushion_text":"mock cushion"}'
                )
            },
            "finish_reason": "stop"
        }],
        "usage": {
            "prompt_tokens": 150,
            "completion_tokens": 60,
            "total_tokens": 210
        }
    }

@app.get("/health")
async def vllm_health():
    return {"status": "ok"}


# ── STT Mock ──────────────────────────────────────────────────
# 실제 호출: {GPU_STT_URL}/whisper/stt
# gpu_stt.transcribe() 참고 - multipart/form-data로 audio bytes 전송
# response: {"text": ..., "duration": ..., "processing_time_ms": ...}
@app.post("/whisper/stt")
async def mock_stt(request: Request):
    await asyncio.sleep(DELAYS["stt"])
    return {
        "text": "프로세스는 독립된 메모리 공간을 가지고 스레드는 해당 공간을 공유합니다.",
        "duration": 3.2,
        "processing_time_ms": 148.5
    }


# ── ElevenLabs TTS Mock ───────────────────────────────────────
# 실제 호출: https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
# ElevenLabsTTSProvider.synthesize() 참고
# response: audio/mpeg binary
@app.post("/v1/text-to-speech/{voice_id}")
async def mock_tts(voice_id: str, request: Request):
    await asyncio.sleep(DELAYS["tts"])
    # 최소한의 유효한 mp3 헤더 (3바이트 ID3 태그)
    dummy_audio = b"ID3" + b"\x00" * 128
    return Response(
        content=dummy_audio,
        media_type="audio/mpeg"
    )
