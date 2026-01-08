// Describes the root sync folder that's in the system
import { Account } from "../Account/Account";
import { DBSyncFolder } from "../Database/Types/DBSyncFolder";

const TAG = 'SyncEngine/SyncFolder';

export class SyncFolder {
    ownerAccount: Account;
    dbSyncFolder: DBSyncFolder;
    syncTimerId: number = 0;

    constructor(dbSyncFolder: DBSyncFolder, account: Account) {
        this.dbSyncFolder = dbSyncFolder;
        this.ownerAccount = account;
    }
}
