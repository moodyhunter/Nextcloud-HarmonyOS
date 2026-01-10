// Describes the root sync folder that's in the system
import { Account } from "../Account/Account";
import { DBLocalSyncFolder } from "../Database/Types/DBLocalSyncFolder";

const TAG = 'SyncEngine/SyncFolder';

export class SyncFolder {
    ownerAccount: Account;
    dbSyncFolder: DBLocalSyncFolder;
    syncTimerId: number = 0;

    constructor(dbSyncFolder: DBLocalSyncFolder, account: Account) {
        this.dbSyncFolder = dbSyncFolder;
        this.ownerAccount = account;
    }
}
