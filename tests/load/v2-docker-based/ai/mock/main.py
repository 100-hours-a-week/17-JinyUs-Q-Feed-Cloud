import asyncio
import time
import random
from fastapi import FastAPI, Request
from fastapi.responses import Response

app = FastAPI()

# 요청마다 범위 내 랜덤 지연을 주는 함수
def llm_delay() -> float:
    # 5~50ms 사이 랜덤 (실측값으로 교체 권장)
    return random.uniform(0.005, 0.050)

def stt_delay() -> float:
    return random.uniform(0.3, 2.0)

def tts_delay() -> float:
    return random.uniform(0.3, 3.0)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/v1/chat/completions")
async def mock_vllm(request: Request):
    await asyncio.sleep(llm_delay())
    return {
        "id": "mock-vllm-001",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": "mock-vllm",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
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


@app.post("/whisper/stt")
async def mock_stt(request: Request):
    await asyncio.sleep(stt_delay())
    return {
        "text": "프로세스는 독립된 메모리 공간을 가지고 스레드는 해당 공간을 공유합니다.",
        "duration": 3.2,
        "processing_time_ms": 148.5
    }


@app.post("/v1/text-to-speech/{voice_id}")
async def mock_tts(voice_id: str, request: Request):
    await asyncio.sleep(tts_delay())
    dummy_audio = b"ID3" + b"\x00" * 128
    return Response(content=dummy_audio, media_type="audio/mpeg")


@app.get("/dummy/audio.mp3")
async def mock_audio_file():
    dummy_mp3 = b"ID3" + b"\x00" * 256
    return Response(content=dummy_mp3, media_type="audio/mpeg")
