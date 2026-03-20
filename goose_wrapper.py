#!/usr/bin/env python3
"""Goose CLI - NVIDIA API Wrapper"""
import sys
import argparse
import json
from openai import OpenAI

def main():
    parser = argparse.ArgumentParser(description='Goose AI Assistant')
    parser.add_argument('-p', '--prompt', help='Prompt to send to AI')
    parser.add_argument('--stream', action='store_true', help='Stream response')
    parser.add_argument('--output-format', help='Output format (stream-json)')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    args = parser.parse_args()

    client = OpenAI(
        base_url="https://integrate.api.nvidia.com/v1",
        api_key="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"
    )

    if args.prompt:
        if args.stream or args.output_format == "stream-json":
            completion = client.chat.completions.create(
                model="moonshotai/kimi-k2-instruct",
                messages=[{"role": "user", "content": args.prompt}],
                temperature=0.6,
                top_p=0.9,
                max_tokens=4096,
                stream=True
            )

            # Output in stream-json format like Claude Code
            print(json.dumps({"type": "system", "subtype": "init"}))
            full_content = ""

            for chunk in completion:
                if chunk.choices and chunk.choices[0].delta.content is not None:
                    content = chunk.choices[0].delta.content
                    full_content += content
                    print(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": content}]}}))

            print(json.dumps({"type": "result", "result": full_content}))
        else:
            completion = client.chat.completions.create(
                model="moonshotai/kimi-k2-instruct",
                messages=[{"role": "user", "content": args.prompt}],
                temperature=0.6,
                max_tokens=4096
            )
            print(completion.choices[0].message.content)
    else:
        print("Usage: goose -p <prompt> [--stream] [--output-format stream-json]")

if __name__ == "__main__":
    main()
