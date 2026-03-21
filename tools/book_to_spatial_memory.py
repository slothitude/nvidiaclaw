#!/usr/bin/env python3
"""
Book to Spatial Memory Ingestion Tool

Converts a reference book into AWR spatial memory format using:
1. Text chunking (paragraphs/sections)
2. Ollama nomic-embed-text for semantic embeddings
3. PCA dimensionality reduction to 3D coordinates
4. JSON output compatible with AWR spatial_memory.gd

Usage:
    python book_to_spatial_memory.py <book_file> [--output memory.json] [--chunk-size 500]
    python book_to_spatial_memory.py <directory> [--output memory.json] [--extensions .rst,.md]

Requirements:
    pip install requests numpy scikit-learn
    ollama pull nomic-embed-text
"""

import argparse
import json
import re
import sys
import time
import uuid
from pathlib import Path
from typing import Optional, List

try:
    import numpy as np
    from sklearn.decomposition import PCA
    import requests
except ImportError:
    print("Install dependencies: pip install requests numpy scikit-learn")
    sys.exit(1)


class OllamaEmbedding:
    """Interface to Ollama's embedding API."""

    def __init__(self, model: str = "nomic-embed-text", base_url: str = "http://localhost:11434"):
        self.model = model
        self.base_url = base_url
        self._check_model()

    def _check_model(self):
        """Check if the model is available and resolve full name."""
        try:
            resp = requests.get(f"{self.base_url}/api/tags", timeout=5)
            models = resp.json().get("models", [])
            model_names = [m["name"] for m in models]

            # Try exact match first
            if self.model in model_names:
                return
            # Try with :latest suffix
            if f"{self.model}:latest" in model_names:
                self.model = f"{self.model}:latest"
                return
            # Try partial match
            for name in model_names:
                if name.startswith(self.model):
                    self.model = name
                    return

            print(f"Model {self.model} not found. Available: {model_names}")
            print(f"Run: ollama pull {self.model}")
            sys.exit(1)
        except requests.exceptions.ConnectionError:
            print("Ollama not running. Start with: ollama serve")
            sys.exit(1)

    def embed(self, text: str) -> list[float]:
        """Get embedding for text."""
        # Truncate very long texts (nomic-embed-text context is ~8192 tokens)
        # Using 2000 chars as safe limit (roughly 500-700 tokens)
        max_chars = 2000
        if len(text) > max_chars:
            text = text[:max_chars]

        try:
            resp = requests.post(
                f"{self.base_url}/api/embeddings",
                json={"model": self.model, "prompt": text},
                timeout=60
            )
            if resp.status_code != 200:
                print(f"  Error: {resp.status_code} - {resp.text[:200]}")
            resp.raise_for_status()
            return resp.json()["embedding"]
        except Exception as e:
            print(f"  Embedding failed for text (len={len(text)}): {str(e)[:100]}")
            raise

    def embed_batch(self, texts: list[str], batch_size: int = 10) -> list[list[float]]:
        """Get embeddings for multiple texts with rate limiting."""
        embeddings = []
        for i, text in enumerate(texts):
            if i > 0 and i % batch_size == 0:
                print(f"  Embedding {i}/{len(texts)}...")
                time.sleep(0.1)  # Rate limiting
            embeddings.append(self.embed(text))
        return embeddings


class TextChunker:
    """Chunks text into semantic units."""

    def __init__(self, chunk_size: int = 500, overlap: int = 50):
        self.chunk_size = chunk_size
        self.overlap = overlap

    def chunk_text(self, text: str) -> list[dict]:
        """Split text into chunks with metadata."""
        # Clean text
        text = re.sub(r'\s+', ' ', text).strip()

        # Split by paragraphs first
        paragraphs = re.split(r'\n\s*\n', text)

        chunks = []
        current_chunk = ""
        chunk_index = 0

        for para in paragraphs:
            para = para.strip()
            if not para:
                continue

            # If paragraph fits, add it
            if len(current_chunk) + len(para) < self.chunk_size:
                current_chunk += " " + para if current_chunk else para
            else:
                # Save current chunk
                if current_chunk:
                    chunks.append({
                        "id": str(uuid.uuid4())[:8],
                        "index": chunk_index,
                        "text": current_chunk.strip(),
                        "char_count": len(current_chunk)
                    })
                    chunk_index += 1

                # Start new chunk with overlap
                if self.overlap > 0 and len(current_chunk) > self.overlap:
                    current_chunk = current_chunk[-self.overlap:] + " " + para
                else:
                    current_chunk = para

        # Don't forget the last chunk
        if current_chunk:
            chunks.append({
                "id": str(uuid.uuid4())[:8],
                "index": chunk_index,
                "text": current_chunk.strip(),
                "char_count": len(current_chunk)
            })

        return chunks


def read_file(filepath: str) -> str:
    """Read text from file (supports .txt, .md, .py, .rst, etc.)."""
    path = Path(filepath)

    if path.suffix == ".pdf":
        try:
            import fitz  # PyMuPDF
            doc = fitz.open(path)
            text = ""
            for page in doc:
                text += page.get_text()
            return text
        except ImportError:
            print("For PDF support: pip install PyMuPDF")
            sys.exit(1)

    # Read as text
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

    # Strip RST directives if it's an RST file
    if path.suffix == ".rst":
        text = strip_rst(text)

    return text


def strip_rst(text: str) -> str:
    """Strip RST directives and formatting from text."""
    # Remove code-block directives
    text = re.sub(r'\.\. code-block::.*?\n', '', text)
    # Remove other directives
    text = re.sub(r'\.\. \w+::.*?\n', '', text)
    # Remove field lists (:field: value)
    text = re.sub(r'^:\w+:.*$', '', text, flags=re.MULTILINE)
    # Remove inline literals ``code``
    text = re.sub(r'``([^`]+)``', r'\1', text)
    # Remove references :ref:`name`
    text = re.sub(r':(?:ref|doc|class|meth|attr|enum|const):`([^`]+)`', r'\1', text)
    # Remove external links `text <url>`__
    text = re.sub(r'`([^`<]+)\s*<[^>]+>`_+', r'\1', text)
    # Remove simple backticks
    text = re.sub(r'`([^`]+)`', r'\1', text)
    # Remove underlines (section headers)
    text = re.sub(r'^[-=~^"\'`#*.]+\s*$', '', text, flags=re.MULTILINE)
    # Remove toctree
    text = re.sub(r'\.\. toctree::.*?(?=\n\n|\Z)', '', text, flags=re.DOTALL)
    # Remove note/warning boxes
    text = re.sub(r'\.\. (note|warning|tip|info|seealso)::.*?(?=\n\n|\Z)', '', text, flags=re.DOTALL)
    # Clean up whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def collect_files(input_path: str, extensions: List[str]) -> List[Path]:
    """Collect all files from path (file or directory) with given extensions."""
    path = Path(input_path)
    files = []

    if path.is_file():
        files.append(path)
    elif path.is_dir():
        for ext in extensions:
            files.extend(path.rglob(f"*{ext}"))
        # Sort for deterministic ordering
        files = sorted(set(files))
    else:
        print(f"Error: {input_path} not found")
        sys.exit(1)

    return files


def embeddings_to_3d(embeddings: list[list[float]]) -> list[dict]:
    """Convert high-dimensional embeddings to 3D coordinates using PCA."""
    embeddings_array = np.array(embeddings)
    n_samples = len(embeddings)

    # Handle edge cases with too few samples for full PCA
    if n_samples < 3:
        # For 1-2 samples, use random-ish positions based on embedding hash
        coords_3d = []
        for i, emb in enumerate(embeddings):
            # Create pseudo-3D position from embedding values
            hash_val = sum(abs(v) * (j + 1) for j, v in enumerate(emb[:100]))
            x = (hash_val % 1000)
            y = ((hash_val * 7) % 1000)
            z = ((hash_val * 13) % 1000)
            # Spread multiple samples apart
            if n_samples == 2:
                x += i * 500
            coords_3d.append([x, y, z])
        coords_3d = np.array(coords_3d)
    else:
        # Use PCA to reduce to 3 dimensions
        n_components = min(3, n_samples)
        pca = PCA(n_components=n_components)
        coords_3d = pca.fit_transform(embeddings_array)

        # Pad to 3D if needed
        if n_components < 3:
            padding = np.zeros((n_samples, 3 - n_components))
            coords_3d = np.hstack([coords_3d, padding])

    # Normalize to reasonable range (0-1000)
    coords_3d = (coords_3d - coords_3d.min(axis=0))
    if coords_3d.max() > 0:
        coords_3d = coords_3d / coords_3d.max() * 1000

    return [
        {"x": float(c[0]), "y": float(c[1]), "z": float(c[2])}
        for c in coords_3d
    ]


def create_spatial_memory(chunks: list[dict], coords: list[dict], source: str) -> dict:
    """Create AWR-compatible spatial memory format."""
    nodes = []

    for chunk, coord in zip(chunks, coords):
        # Create a short concept name from the chunk
        concept_preview = chunk["text"][:50].replace("\n", " ").strip()
        if len(chunk["text"]) > 50:
            concept_preview += "..."

        # Get source file from chunk metadata if available
        chunk_source = chunk.get("source", source)

        node = {
            "id": chunk["id"],
            "concept": f"chunk_{chunk['index']}_{concept_preview}",
            "location": coord,
            "metadata": {
                "semantic_type": "text_chunk",
                "source": chunk_source,
                "char_count": chunk["char_count"],
                "chunk_index": chunk["index"],
                "full_text": chunk["text"][:1000],  # Store first 1000 chars
            },
            "connections": [],
            "created_at": int(time.time() * 1000),
            "accessed_at": int(time.time() * 1000),
            "access_count": 0,
        }

        # Connect to adjacent chunks from same source
        if chunk["index"] > 0:
            node["connections"].append({
                "concept": f"chunk_{chunk['index'] - 1}",
                "type": "previous",
                "strength": 1.0
            })
        if chunk["index"] < len(chunks) - 1:
            node["connections"].append({
                "concept": f"chunk_{chunk['index'] + 1}",
                "type": "next",
                "strength": 1.0
            })

        nodes.append(node)

    return {
        "cell_size": 10.0,
        "path_sample_interval": 5.0,
        "nodes": nodes,
        "stats": {
            "source": source,
            "total_chunks": len(chunks),
            "ingestion_timestamp": int(time.time() * 1000)
        }
    }


def main():
    parser = argparse.ArgumentParser(
        description="Convert a book/document to AWR spatial memory format"
    )
    parser.add_argument("input", help="Input file or directory (txt, md, pdf, rst, etc.)")
    parser.add_argument("--output", "-o", default="spatial_memory.json",
                        help="Output JSON file (default: spatial_memory.json)")
    parser.add_argument("--chunk-size", "-c", type=int, default=500,
                        help="Chunk size in characters (default: 500)")
    parser.add_argument("--overlap", type=int, default=50,
                        help="Chunk overlap in characters (default: 50)")
    parser.add_argument("--model", "-m", default="nomic-embed-text",
                        help="Ollama embedding model (default: nomic-embed-text)")
    parser.add_argument("--limit", "-l", type=int, default=None,
                        help="Limit number of chunks (for testing)")
    parser.add_argument("--extensions", "-e", default=".rst,.md,.txt",
                        help="Comma-separated file extensions for directory mode (default: .rst,.md,.txt)")
    parser.add_argument("--max-files", type=int, default=None,
                        help="Maximum number of files to process (for testing)")

    args = parser.parse_args()

    # Parse extensions
    extensions = [ext.strip() if ext.strip().startswith('.') else f'.{ext.strip()}'
                  for ext in args.extensions.split(',')]

    print(f"=== Book to Spatial Memory ===")
    print(f"Input: {args.input}")
    print(f"Model: {args.model}")
    print(f"Chunk size: {args.chunk_size}")
    print(f"Extensions: {extensions}")
    print()

    # Collect files
    print("Collecting files...")
    files = collect_files(args.input, extensions)
    print(f"  Found {len(files)} files")

    if args.max_files:
        files = files[:args.max_files]
        print(f"  Limited to: {len(files)} files")

    # Process all files
    chunker = TextChunker(chunk_size=args.chunk_size, overlap=args.overlap)
    all_chunks = []
    global_chunk_index = 0

    for i, filepath in enumerate(files):
        if i % 50 == 0:
            print(f"  Processing file {i+1}/{len(files)}: {filepath.name}")

        try:
            text = read_file(str(filepath))
            if len(text.strip()) < 50:  # Skip very short files
                continue

            file_chunks = chunker.chunk_text(text)

            # Add source metadata and reindex globally
            for chunk in file_chunks:
                chunk["index"] = global_chunk_index
                chunk["source"] = str(filepath.relative_to(Path(args.input).parent) if Path(args.input).is_dir() else filepath.name)
                global_chunk_index += 1

            all_chunks.extend(file_chunks)
        except Exception as e:
            print(f"  Warning: Could not process {filepath}: {e}")

    print(f"  Total characters: {sum(c['char_count'] for c in all_chunks):,}")
    print(f"  Total chunks: {len(all_chunks)}")

    # Limit for testing
    if args.limit:
        all_chunks = all_chunks[:args.limit]
        print(f"  Limited to: {len(all_chunks)} chunks")

    if len(all_chunks) == 0:
        print("Error: No chunks to process")
        sys.exit(1)

    # Get embeddings
    print("Getting embeddings from Ollama...")
    embedder = OllamaEmbedding(model=args.model)
    embeddings = embedder.embed_batch([c["text"] for c in all_chunks])
    print(f"  Embedding dimensions: {len(embeddings[0])}")

    # Convert to 3D
    print("Converting embeddings to 3D coordinates...")
    coords = embeddings_to_3d(embeddings)

    # Create spatial memory
    print("Creating spatial memory structure...")
    source_name = Path(args.input).name
    memory = create_spatial_memory(all_chunks, coords, source=source_name)

    # Save output
    print(f"Saving to {args.output}...")
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(memory, f, indent=2, ensure_ascii=False)

    print()
    print("=== Done! ===")
    print(f"Created {len(memory['nodes'])} memory nodes")
    print()
    print("To load in AWR:")
    print(f'  var memory = SpatialMemory.load_from("res://{args.output}")')


if __name__ == "__main__":
    main()
