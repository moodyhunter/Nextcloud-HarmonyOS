export {
    add, remove, connect, disconnect, registerFileChangeMonitor, updateCustomAlias, setLocalFileState
} from 'libcloudsync.so';

export enum FileChangeOperationType {
    CREATE = 0,
    DELETE = 1,
    MOVE_FROM = 2,
    MOVE_TO = 3,
    CLOSE_WRITE = 4,
    SYNC_FOLDER_INVALID = 5,
}

export interface FileChangeInfo {
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

export interface SyncFileState {
    name: string;
    size: number;
    syncState: SyncState;
}
