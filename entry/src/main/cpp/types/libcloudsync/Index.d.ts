export enum FileChangeOperationType {
  CREATE = 0,
  DELETE = 1,
  MOVE_FROM = 2,
  MOVE_TO = 3,
  CLOSE_WRITE = 4,
  SYNC_FOLDER_INVALID = 5,
}

interface FileChangeInfo {
  fileId: string;
  parentFileId: string;
  relativePath: string;
  operationType: FileChangeOperationType;
  size: number;
  mtime: number;
}

export enum SyncState {
  IDLE = 0,
  SYNCING = 1,
  SUCCEEDED = 2,
  FAILED = 3,
  CANCELED = 4,
  CONFLICTED = 5,
}

interface SyncFileState {
  name: string;
  size: number;
  syncState: SyncState;
}


export function add(alias: string, path: string): number;

export function remove(path: string): number;

export function connect(path: string): number;

export function disconnect(path: string): number;

export function registerFileChangeMonitor(callback: (fileChangeInfo: FileChangeInfo) => void): void;

export function setLocalFileState(path: string, entries: SyncFileState[]): number;

export function updateCustomAlias(path: string, newAlias: string): number;
