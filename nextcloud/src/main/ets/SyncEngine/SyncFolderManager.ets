// Manage mappings between Account -=> SyncFolder
import { Logger } from '../Utils/Logger';
import { DBManager } from '../Database/DBManager';
import { Account } from '../Account/Account';
import { DBAccount, DBAccountTableInfo as DBAccountTable } from '../Database/Types/DBAccount';
import { NCommon } from '../Common';
import { SyncFolder } from './SyncFolder';
import { DBLocalSyncFolderTableInfo as DBLocalSyncFolderTable } from '../Database/Types/DBLocalSyncFolder';

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

    public hasAccounts(): boolean {
        return this.accounts.size > 0;
    }

    public getAccountById(accountId: number): Account {
        let account = this.accounts.get(accountId);
        if (!account) {
            throw new Error(`getAccountById: account id ${accountId} not found`);
        }
        return account;
    }

    public getAllAccounts(): Account[] {
        let values = this.accounts.values();
        return Array.from(values);
    }

    public async addAccount(account: Account): Promise<void> {
        await this.dbManager.storeItem(account.dbAccount);
    }

    private async loadSyncFolders() {
        let dbFolders = await this.dbManager.getItems(DBLocalSyncFolderTable);
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
        let dbAccounts = await this.dbManager.getItems(DBAccountTable);
        for (let dbAccount of dbAccounts) {
            let account = new Account(dbAccount);
            this.accounts.set(dbAccount.id, account);
        }

        if (dbAccounts.length === 0) {
            // No accounts found in database, migrate from preferences if possible
            let prefServer = NCommon.Preference.getPref('login.server', '');
            let prefUsername = NCommon.Preference.getPref('login.username', '');
            let prefPassword = NCommon.Preference.getPref('login.appPassword', '');
            if (prefPassword.length > 0) {
                Logger.Info(TAG, `loadAccounts: no accounts found, migrate default account '${prefUsername}@${prefServer}' from preferences`);
                let dbAccount = new DBAccount(0, prefServer, prefUsername, prefPassword);
                this.accounts.set(dbAccount.id, new Account(dbAccount));
                await this.dbManager.storeItem(dbAccount);
            } else {
                Logger.Info(TAG, `loadAccounts: no accounts found, possibly first run`);
            }
        } else {
            Logger.Info(TAG, `loadAccounts: ${dbAccounts.length} accounts loaded`);
        }
    }
}
