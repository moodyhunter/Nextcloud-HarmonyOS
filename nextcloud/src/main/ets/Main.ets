/**
 * nextcloud initialization
 */
import { DEBUG } from "../../../BuildProfile";
import { SyncFolderManager } from "./SyncEngine/SyncFolderManager";
import { Logger } from "./Utils/Logger";
import { DBManager } from "./Database/DBManager";
import { NCommon } from "./Common";

const TAG = 'Nextcloud/Init';

const DEFAULT_DATABASE_NAME = 'nextcloud_data.db';
const DEBUG_DATABASE_NAME = 'nextcloud_data-debug.db';

class NextcloudImpl {
    private dbManager: DBManager;
    private syncFolderManager: SyncFolderManager;

    constructor() {
        Logger.Info(TAG, `constructor`);
        this.dbManager = new DBManager();
        this.syncFolderManager = new SyncFolderManager(this.dbManager);
    }

    async initialize(context: Context): Promise<void> {
        Logger.Info(TAG, `initialize: enter`);
        await this.dbManager.initDataStore(context, DEBUG ? DEBUG_DATABASE_NAME : DEFAULT_DATABASE_NAME);
        await this.dbManager.upgradeDatabase();
        await this.syncFolderManager.loadData();
    }
}

export async function InitialiseNextcloud(context: Context): Promise<void> {
    Logger.Info(TAG, `init`);
    NCommon.Initialise(context);
    Nextcloud = new NextcloudImpl();
    await Nextcloud.initialize(context);
}


export let Nextcloud: NextcloudImpl;
