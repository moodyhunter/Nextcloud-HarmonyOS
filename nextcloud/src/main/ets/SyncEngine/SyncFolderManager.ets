// Manage mappings between Account -=> SyncFolder
import { Logger } from '../Utils/Logger';
import { DBManager } from '../Database/DBManager';
import { Account } from '../Account/Account';
import { DBAccount, DBAccountFactory } from '../Database/Types/DBAccount';
import { NCommon } from '../Common';
import { DBSyncFolder, DBSyncFolderFactory } from '../Database/Types/DBSyncFolder';
import { SyncFolder } from './SyncFolder';

const TAG = 'SyncEngine/SyncFolderManager';

export class SyncFolderManager {
    private dbManager: DBManager;
    private accounts: Map<number, Account> = new Map();
    private folders: Map<number, SyncFolder> = new Map();

    constructor(dbManager: DBManager) {
        Logger.Info(TAG, `constructor`);
        this.dbManager = dbManager;
    }

    public async loadData(): Promise<void> {
        await this.loadAccounts();
        await this.loadSyncFolders();
    }

    private async loadSyncFolders() {
        let dbFolders = await this.dbManager.getObjects(DBSyncFolderFactory);
        for (let dbFolder of dbFolders) {
            let ownerAccount = this.accounts.get(dbFolder.accountId);
            if (!ownerAccount) {
                Logger.Error(TAG, `loadSyncFolders: no owner account found for folder id ${dbFolder.id}, account id ${dbFolder.accountId}`);
                continue;
            }
            let syncFolder = new SyncFolder(dbFolder, ownerAccount);
            this.folders.set(dbFolder.id, syncFolder);
        }
    }

    private async loadAccounts(): Promise<void> {
        let dbAccounts = await this.dbManager.getObjects(DBAccountFactory);
        for (let dbAccount of dbAccounts) {
            let account = new Account(dbAccount);
            this.accounts.set(dbAccount.id, account);
        }

        if (NCommon.Preference.username.length > 0 && dbAccounts.length === 0) {
            Logger.Info(TAG, `loadAccounts: no accounts found, migrate default account`);
            let dbAccount = new DBAccount(0, NCommon.Preference.username, NCommon.Preference.password, NCommon.Preference.hostname);
            this.accounts.set(dbAccount.id, new Account(dbAccount));
            await this.dbManager.storeObject(dbAccount);
        }
    }
}
