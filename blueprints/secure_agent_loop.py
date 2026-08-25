#!/usr/bin/env python3
# Sterile Python Client Implementation (Inside Container Namespace)
# Communicates with Local Open-Weights Inference Runner via Shared Domain Socket File
import socket
import json
import os

class SterileAgentClient:
    def __init__(self, socket_path="/workspace/ollama.sock"):
        self.socket_path = socket_path

    def generate_instruction(self, user_prompt):
        # Establish raw stream connection through the physical UNIX socket file
        if not os.path.exists(self.socket_path):
            raise FileNotFoundError(f"IPC Boundary Broken: {self.socket_path} missing.")

        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(self.socket_path)

        # Build the payload completely devoid of vendor pre-prompts
        payload = {
            "model": "llama3",
            "prompt": user_prompt,
            "stream": False,
            "options": {
                "temperature": 0.0  # Eliminate non-deterministic probabilistic drift
            }
        }

        # Transmit raw byte payload through the system kernel socket channel
        client.sendall(json.dumps(payload).encode('utf-8'))

        # Collect returned token fragments
        response_data = b""
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            response_data += chunk

        client.close()
        return json.loads(response_data.decode('utf-8'))['response']
if __name__ == "__main__":
    agent = SterileAgentClient()  # Execution remains safely contained inside the cgroup namespace
    raw_output = agent.generate_instruction("Parse inputs located within /workspace/io/data.txt")
    print(f"Contained Agent Execution Output: {raw_output}")
