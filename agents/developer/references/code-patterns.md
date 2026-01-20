# R3F Component Patterns Reference

## Basic Component Template

```tsx
import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Mesh } from 'three';

interface MyComponentProps {
  position?: [number, number, number];
  color?: string;
}

export function MyComponent({ position = [0, 0, 0], color = 'royalblue' }: MyComponentProps) {
  const meshRef = useRef<Mesh>(null);

  useFrame((state, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += delta;
    }
  });

  return (
    <mesh ref={meshRef} position={position}>
      <boxGeometry />
      <meshStandardMaterial color={color} />
    </mesh>
  );
}
```

## Physics Component Template

```tsx
import { useRef } from 'react';
import { RigidBody, RapierRigidBody } from '@react-three/rapier';
import { useFrame } from '@react-three/fiber';

interface PhysicsObjectProps {
  position?: [number, number, number];
  onCollision?: () => void;
}

export function PhysicsObject({ position = [0, 0, 0], onCollision }: PhysicsObjectProps) {
  const rigidBodyRef = useRef<RapierRigidBody>(null);

  const handleCollisionEnter = () => {
    onCollision?.();
  };

  return (
    <RigidBody ref={rigidBodyRef} position={position} onCollisionEnter={handleCollisionEnter}>
      <mesh>
        <boxGeometry />
        <meshStandardMaterial color="orange" />
      </mesh>
    </RigidBody>
  );
}
```

## Game Loop Component Template

```tsx
import { useFrame } from '@react-three/fiber';
import { useGameStore } from '@/store/gameStore';

export function GameLoop() {
  const updateGame = useGameStore((state) => state.update);

  useFrame((state, delta) => {
    // Cap delta to prevent physics issues
    const cappedDelta = Math.min(delta, 1 / 30);

    // Update game state
    updateGame(cappedDelta);
  });

  return null;
}
```

## Custom Shader Template

```tsx
import { useRef, useMemo } from 'react';
import { shaderMaterial } from '@react-three/drei';
import { extend, useFrame } from '@react-three/fiber';
import * as THREE from 'three';

const CustomShaderMaterial = shaderMaterial(
  {
    uTime: 0,
    uColor: new THREE.Color('hotpink'),
  },
  // Vertex shader
  `
    uniform float uTime;
    varying vec2 vUv;

    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  // Fragment shader
  `
    uniform float uTime;
    uniform vec3 uColor;
    varying vec2 vUv;

    void main() {
      gl_FragColor = vec4(uColor, 1.0);
    }
  `
);

extend({ CustomShaderMaterial });

// Add TypeScript declaration
declare global {
  namespace JSX {
    interface IntrinsicElements {
      customShaderMaterial: any;
    }
  }
}

export function ShaderMesh() {
  const materialRef = useRef<any>(null);

  useFrame((state) => {
    if (materialRef.current) {
      materialRef.current.uTime = state.clock.elapsedTime;
    }
  });

  return (
    <mesh>
      <planeGeometry args={[4, 4, 32, 32]} />
      <customShaderMaterial ref={materialRef} />
    </mesh>
  );
}
```

## Zustand Store Template

```tsx
import { create } from 'zustand';

interface GameState {
  // State
  phase: 'loading' | 'menu' | 'playing' | 'paused' | 'gameOver';
  score: number;
  players: Map<string, Player>;

  // Actions
  setPhase: (phase: GameState['phase']) => void;
  incrementScore: (amount: number) => void;
  addPlayer: (player: Player) => void;
  removePlayer: (id: string) => void;
  update: (delta: number) => void;
}

interface Player {
  id: string;
  position: { x: number; y: number; z: number };
  health: number;
}

export const useGameStore = create<GameState>((set, get) => ({
  // Initial state
  phase: 'loading',
  score: 0,
  players: new Map(),

  // Actions
  setPhase: (phase) => set({ phase }),

  incrementScore: (amount) => set((state) => ({ score: state.score + amount })),

  addPlayer: (player) =>
    set((state) => ({
      players: new Map(state.players).set(player.id, player),
    })),

  removePlayer: (id) =>
    set((state) => {
      const players = new Map(state.players);
      players.delete(id);
      return { players };
    }),

  update: (delta) => {
    const { phase } = get();
    if (phase !== 'playing') return;

    // Update game logic here
  },
}));
```

## Input Handler Template

```tsx
import { useEffect, useCallback } from 'react';
import { useGameStore } from '@/store/gameStore';

interface InputState {
  forward: boolean;
  backward: boolean;
  left: boolean;
  right: boolean;
  jump: boolean;
}

export function useInput(): InputState {
  const [input, setInput] = useState<InputState>({
    forward: false,
    backward: false,
    left: false,
    right: false,
    jump: false,
  });

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      setInput((prev) => ({
        ...prev,
        forward: key === 'w' || key === 'arrowup' ? true : prev.forward,
        backward: key === 's' || key === 'arrowdown' ? true : prev.backward,
        left: key === 'a' || key === 'arrowleft' ? true : prev.left,
        right: key === 'd' || key === 'arrowright' ? true : prev.right,
        jump: key === ' ' ? true : prev.jump,
      }));
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      setInput((prev) => ({
        ...prev,
        forward: key === 'w' || key === 'arrowup' ? false : prev.forward,
        backward: key === 's' || key === 'arrowdown' ? false : prev.backward,
        left: key === 'a' || key === 'arrowleft' ? false : prev.left,
        right: key === 'd' || key === 'arrowright' ? false : prev.right,
        jump: key === ' ' ? false : prev.jump,
      }));
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, []);

  return input;
}
```
