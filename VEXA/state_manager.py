#!/usr/bin/env python3
"""State manager for VEXA — manages system states and transitions."""

import asyncio
from enum import Enum
from typing import Optional, Callable, List
from datetime import datetime


class VexaState(Enum):
    IDLE        = "IDLE"
    LISTENING   = "LISTENING"
    THINKING    = "THINKING"
    SPEAKING    = "SPEAKING"
    PC_CONTROL  = "PC_CONTROL"
    AGENT       = "AGENT"


class StateManager:
    def __init__(self):
        self._state = VexaState.IDLE
        self._previous: Optional[VexaState] = None
        self._history: list = []
        self._subscribers: List[Callable] = []
        self._metadata: dict = {}

    @property
    def state(self) -> VexaState:
        return self._state

    @property
    def state_name(self) -> str:
        return self._state.value

    async def set_state(self, new_state: VexaState, metadata: dict = None):
        if new_state == self._state:
            return

        self._previous = self._state
        self._state = new_state
        self._metadata = metadata or {}

        self._history.append({
            "timestamp": datetime.now().isoformat(),
            "from": self._previous.value,
            "to": new_state.value,
            "metadata": self._metadata,
        })

        for cb in self._subscribers:
            try:
                if asyncio.iscoroutinefunction(cb):
                    await cb(new_state, self._metadata)
                else:
                    cb(new_state, self._metadata)
            except Exception as e:
                print(f"[StateManager] Error en subscriber: {e}")

    def subscribe(self, callback: Callable):
        self._subscribers.append(callback)

    def get_status(self) -> dict:
        return {
            "state":    self._state.value,
            "previous": self._previous.value if self._previous else None,
            "metadata": self._metadata,
            "history":  self._history[-10:],
        }
