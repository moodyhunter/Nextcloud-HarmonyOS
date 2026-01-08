// Manage mappings between Account -=> SyncFolder
import { Logger } from '../Utils/Logger';
import { StorageAdapterImpl } from '../Utils/StorageAdapter';

const TAG = 'SyncEngine/SyncFolderManager';

export class SyncFolderManager {
    private storageAdapter: StorageAdapterImpl;

    constructor(storageAdapter: StorageAdapterImpl) {
        Logger.Info(TAG, `constructor`);
        this.storageAdapter = storageAdapter;
    }

    public async init(): Promise<void> {
        // load accounts from storage
        this.loadAccounts();

        // load folders from storage
        this.loadFolders();
    }

    private loadFolders() {
    }

    private loadAccounts() {
    }
}
