import requests
import time
import json

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
#MODEL = "qwen3:14b"  # change to your installed model if needed
MODEL = "qwen3:4b"
PROMPT = "why is the sky blue?"


def run_test():
    payload = {
        "model": MODEL,
        "prompt": PROMPT,
        "stream": False  # easier to measure full response
    }

    print("Sending request to Ollama...\n")
    start_time = time.time()

    response = requests.post(OLLAMA_URL, json=payload)
    end_time = time.time()

    if response.status_code != 200:
        print(f"Error: {response.status_code}")
        print(response.text)
        return

    data = response.json()

    # Extract info
    output_text = data.get("response", "")
    total_duration_ns = data.get("total_duration", 0)
    prompt_eval_count = data.get("prompt_eval_count", 0)
    prompt_eval_duration = data.get("prompt_eval_duration", 0)
    eval_count = data.get("eval_count", 0)
    eval_duration = data.get("eval_duration", 0)

    # Convert nanoseconds → seconds
    total_time = total_duration_ns / 1e9 if total_duration_ns else (end_time - start_time)
    prompt_time = prompt_eval_duration / 1e9 if prompt_eval_duration else None
    generation_time = eval_duration / 1e9 if eval_duration else None

    # Compute throughput
    prompt_tps = prompt_eval_count / prompt_time if prompt_time and prompt_time > 0 else None
    gen_tps = eval_count / generation_time if generation_time and generation_time > 0 else None

    # Output results
    print("=== MODEL RESPONSE ===")
    print(output_text)
    print("\n=== PERFORMANCE METRICS ===")
    print(f"Total time: {total_time:.3f} sec")

    if prompt_time:
        print(f"Prompt tokens: {prompt_eval_count}")
        print(f"Prompt processing time: {prompt_time:.3f} sec")
        print(f"Prompt throughput: {prompt_tps:.2f} tokens/sec")

    if generation_time:
        print(f"Generated tokens: {eval_count}")
        print(f"Generation time: {generation_time:.3f} sec")
        print(f"Generation throughput: {gen_tps:.2f} tokens/sec")


if __name__ == "__main__":
    run_test()
