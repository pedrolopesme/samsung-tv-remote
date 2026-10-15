#!/usr/bin/env python3
"""Envia um magic packet Wake-on-LAN (mesma lógica de Core/TV/WakeOnLAN.swift).

Uso: python3 scripts/wake.py 80:47:86:00:00:00 [broadcast]
"""
import re
import socket
import sys

def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    mac = re.sub(r"[^0-9a-fA-F]", "", sys.argv[1])
    if len(mac) != 12:
        print(f"MAC inválido: {sys.argv[1]}", file=sys.stderr)
        return 1
    broadcast = sys.argv[2] if len(sys.argv) > 2 else "255.255.255.255"
    packet = b"\xff" * 6 + bytes.fromhex(mac) * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        for _ in range(3):
            s.sendto(packet, (broadcast, 9))
    print(f"Magic packet ({len(packet)} bytes) enviado para {broadcast}:9")
    return 0

if __name__ == "__main__":
    sys.exit(main())
