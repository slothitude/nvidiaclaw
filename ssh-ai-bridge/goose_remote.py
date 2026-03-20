#!/usr/bin/env python3
"""Goose CLI - NVIDIA API Wrapper"""
import sys
import argparse
import json
from openai import OpenAI

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', dest='prompt')
    parser.add_argument('--stream', action='store_true')
    parser.add_argument('--output-format')
    parser.add_argument('--verbose', action='store_true')
    args = parser.parse_args()

    client = OpenAI(
        base_url="https://integrate.api.nvidia.com/v1",
        api_key="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"
    )

    if args.prompt:
        completion = client.chat.completions.create(
            model="moonshotai/kimi-k2-instruct",
            messages=[{"role": "user", "content": args.prompt}],
            temperature=0.6,
            max_tokens=4096,
            stream=True
        )
        full = ""
        for chunk in completion:
            if chunk.choices and chunk.choices[0].delta.content:
                full += chunk.choices[0].delta.content
        print(json.dumps({"type": "result", "result": full}))
    else:
        print("Usage: goose -p <prompt> [--stream] [--output-format stream-json] [--verbose]")

if __name__ == "__main__":
    main()
