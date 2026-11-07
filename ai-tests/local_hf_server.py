#!/usr/bin/env python3
"""
Servidor local que imita la API de Hugging Face (hf-inference) con los MISMOS
modelos de código abierto que usa el backend, ejecutados en tu computadora.
Sirve para medir la efectividad sin gastar créditos: los modelos se descargan
gratis y el cálculo ocurre en tu equipo.

Instalación (una vez):
    pip install torch --index-url https://download.pytorch.org/whl/cpu
    pip install transformers sentence-transformers

Uso (terminal 1):
    python local_hf_server.py            # puerto 8000 por defecto

Uso (terminal 2, carpeta ai-tests, PowerShell):
    $env:HF_API_KEY="hf_local"
    $env:HF_BASE_URL="http://127.0.0.1:8000/hf-inference/models"
    node run_tests.js hf --delay=0

La primera vez se descargan unos 3 GB de modelos desde huggingface.co
(la descarga no requiere créditos). El token no se valida.

IMPORTANTE: los resultados de efectividad son los del modelo, pero la latencia
y los códigos HTTP son los de este servidor local, no los del servicio de
Hugging Face.
"""

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

TOX = "s-nlp/roberta_toxicity_classifier"
ZS = "joeddav/xlm-roberta-large-xnli"
SIM = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


class RealModels:
    """Carga los tres modelos reales de Hugging Face en la computadora."""

    def __init__(self):
        from transformers import pipeline
        from sentence_transformers import SentenceTransformer

        print("Cargando modelos (la primera vez se descargan, ~3 GB)...", flush=True)
        self._tox = pipeline("text-classification", model=TOX, top_k=None)
        self._zs = pipeline("zero-shot-classification", model=ZS)
        self._sim = SentenceTransformer(SIM)
        print("Modelos listos.", flush=True)

    def toxicity(self, text):
        out = self._tox(text)
        if out and isinstance(out[0], list):  # según la versión de transformers
            out = out[0]
        return [[{"label": r["label"], "score": float(r["score"])} for r in out]]

    def zero_shot(self, text, labels, multi_label):
        r = self._zs(text, candidate_labels=labels, multi_label=multi_label)
        return {"labels": r["labels"], "scores": [float(s) for s in r["scores"]]}

    def similarity(self, source, sentences):
        from sentence_transformers import util

        emb = self._sim.encode([source] + list(sentences), convert_to_tensor=True)
        return [float(x) for x in util.cos_sim(emb[0], emb[1:])[0].tolist()]


def make_handler(models):
    class Handler(BaseHTTPRequestHandler):
        def _send(self, code, obj):
            data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            try:
                length = int(self.headers.get("Content-Length", 0))
                body = json.loads(self.rfile.read(length) or b"{}")
            except Exception:
                return self._send(400, {"error": "Cuerpo JSON inválido"})

            inputs = body.get("inputs")
            if inputs is None:
                return self._send(400, {"error": "Falta el campo 'inputs'"})

            try:
                if TOX in self.path:
                    if not isinstance(inputs, str):
                        return self._send(400, {"error": "inputs debe ser texto"})
                    return self._send(200, models.toxicity(inputs))

                if ZS in self.path:
                    params = body.get("parameters") or {}
                    labels = params.get("candidate_labels")
                    if not isinstance(inputs, str) or not labels:
                        return self._send(400, {"error": "Faltan inputs o candidate_labels"})
                    return self._send(200, models.zero_shot(inputs, labels, bool(params.get("multi_label", False))))

                if SIM in self.path:
                    src = inputs.get("source_sentence") if isinstance(inputs, dict) else None
                    sentences = inputs.get("sentences") if isinstance(inputs, dict) else None
                    if not isinstance(src, str) or not isinstance(sentences, list):
                        return self._send(400, {"error": "Faltan source_sentence o sentences"})
                    return self._send(200, models.similarity(src, sentences))
            except Exception as exc:  # error del modelo
                return self._send(500, {"error": str(exc)})

            return self._send(404, {"error": "Modelo no disponible en este servidor local"})

        def log_message(self, fmt, *args):  # silencia el registro por solicitud
            pass

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    models = RealModels()
    server = HTTPServer(("127.0.0.1", args.port), make_handler(models))
    print(f"Servidor local listo en http://127.0.0.1:{args.port}/hf-inference/models", flush=True)
    print("Déjalo abierto y ejecuta las pruebas en otra terminal. Ctrl+C para detenerlo.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()