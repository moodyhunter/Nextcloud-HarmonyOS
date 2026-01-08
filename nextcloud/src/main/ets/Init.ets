/**
 * nextcloud initialization
 */
import { DEBUG } from "../../../BuildProfile";
import { SyncFolderManager } from "./SyncEngine/SyncFolderManager";
import { Logger } from "./Utils/Logger";
import { StorageAdapterImpl } from "./Utils/StorageAdapter";

const TAG = 'Nextcloud/Init';

const DEFAULT_DATABASE_NAME = 'nextcloud_data.db';
const DEBUG_DATABASE_NAME = 'nextcloud_data-debug.db';

class NextcloudImpl {
    private storageAdapter: StorageAdapterImpl;
    private syncFolderManager: SyncFolderManager;

    constructor() {
        Logger.Info(TAG, `constructor`);
        this.storageAdapter = new StorageAdapterImpl();
        this.syncFolderManager = new SyncFolderManager(this.storageAdapter);
    }

    async initialize(context: Context): Promise<void> {
        Logger.Info(TAG, `initialize: enter`);
        await this.storageAdapter.initDataStore(context, DEBUG ? DEBUG_DATABASE_NAME : DEFAULT_DATABASE_NAME);
        await this.storageAdapter.upgradeDatabase();
        await this.syncFolderManager.init();
    }
}

export async function InitialiseNextcloud(context: Context): Promise<void> {
    Logger.Info(TAG, `init`);
    Nextcloud = new NextcloudImpl();
    await Nextcloud.initialize(context);
}


export let Nextcloud: NextcloudImpl;
