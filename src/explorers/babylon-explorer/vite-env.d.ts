
interface ImportMetaEnv {
  readonly VITE_BABYLON_RPC: string
  readonly VITE_BABYLON_API: string
  readonly VITE_STAKING_API: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
