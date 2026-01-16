/**
 * nextcloud initialization
 */
import { DEBUG } from '../../../BuildProfile';
import { SyncFolderManager } from './SyncEngine/SyncFolderManager';
import { Logger } from './Utils/Logger';
import { DBManager } from './Database/DBManager';
import { NCommon } from './Common';
import { Account } from './Account/Account';
import { DBAccount, DBAccountTableInfo } from './Database/DbTypes/DBAccount';

const TAG = 'Nextcloud/Init';

const DEFAULT_DATABASE_NAME = 'nextcloud_data.db';
const DEBUG_DATABASE_NAME = 'nextcloud_data-debug.db';

@Observed
export class NextcloudImpl {
    private dbManager_: DBManager;
    private syncFolderManager_: SyncFolderManager;
    private accounts_: Map<number, Account> = new Map();

    constructor() {
        Logger.Info(TAG, `constructor`);
        this.dbManager_ = new DBManager();
        this.syncFolderManager_ = new SyncFolderManager(this.dbManager_);
    }

    public async initialize(context: Context): Promise<void> {
        Logger.Info(TAG, `initialize: enter`);
        await this.dbManager_.initDataStore(context, DEBUG ? DEBUG_DATABASE_NAME : DEFAULT_DATABASE_NAME);
        await this.dbManager_.upgradeDatabase();
        await this.loadAccounts();
        await this.syncFolderManager_.loadSyncFolders();
    }

    public getSyncFolderManager(): SyncFolderManager {
        return this.syncFolderManager_;
    }

    public getAccountById(accountId: number): Account {
        let account = this.accounts_.get(accountId);
        if (account) {
            return account;
        }

        Logger.Error(TAG, `getAccountById: account id ${accountId} not found, available accounts: ${Array.from(this.accounts_.keys()).join(',')}`);
        if (this.accounts_.size > 0) {
            account = this.accounts_.values().next().value;
            Logger.Info(TAG, `getAccountById: returning first available account id ${account!.dbAccount.id}`);
            return account!;
        } else {
            throw new Error(`No accounts available`);
        }
    }

    public getAllAccounts(): Account[] {
        let values = this.accounts_.values();
        return Array.from(values);
    }

    public hasAccounts(): boolean {
        return this.accounts_.size > 0;
    }

    public async addAccount(account: Account, addToDb: boolean = true): Promise<void> {
        this.accounts_.set(account.dbAccount.id, account);
        if (addToDb) {
            await this.dbManager_.createItem(account.dbAccount);
        }
    }

    public async recreateDatabase() {
        await this.dbManager_.dropDatabase();
    }

    private async loadAccounts(): Promise<void> {
        let dbAccounts = await this.dbManager_.getItems(DBAccountTableInfo);
        for (let dbAccount of dbAccounts) {
            await this.addAccount(new Account(dbAccount), false);
        }

        if (dbAccounts.length === 0) {
            await this.migrateAccount();
        } else {
            Logger.Info(TAG, `loadAccounts: ${dbAccounts.length} accounts loaded`);
        }
    }

    /**
     * No accounts found in database, migrate from preferences if possible
     */
    private async migrateAccount() {
        let prefServer = NCommon.Preference.getPref('login.server', '');
        let prefUsername = NCommon.Preference.getPref('login.username', '');
        let prefPassword = NCommon.Preference.getPref('login.appPassword', '');
        if (prefServer.length > 0 && prefUsername.length > 0 && prefPassword.length > 0) {
            Logger.Info(TAG, `migrateAccount: no accounts found, migrate default account '${prefUsername}@${prefServer}' from preferences`);
            let dbAccount = new DBAccount(0, prefServer, prefUsername, prefPassword);
            await this.addAccount(new Account(dbAccount));
        } else {
            Logger.Info(TAG, `migrateAccount: no accounts found, possibly first run`);
        }
    }
}

export async function InitialiseNextcloud(context: Context): Promise<void> {
    Logger.Info(TAG, `init`);
    NCommon.Initialise(context);
    Nextcloud = new NextcloudImpl();
    await Nextcloud.initialize(context);
}


export let Nextcloud: NextcloudImpl;
